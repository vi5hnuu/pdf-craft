import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/http_state.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/tool_result_handler.dart';
import 'package:pdf_craft/widgets/processing_overlay.dart';

/// Shared behaviour for every server-backed tool screen, so each view no longer
/// re-implements the same bloc wiring, cancel handling, navigation and overlay.
///
/// A tool screen mixes this in and typically:
///   1. calls [resetToolState] in `initState` (clears stale done/error),
///   2. dispatches work through [runTool] (gives the request a CancelToken),
///   3. routes its `BlocConsumer.listener` through [handleToolState],
///   4. puts [processingOverlay] as the last child of its body Stack.
///
/// Combined with [ToolResultHandler] it also drives the rate-app prompt.
mixin ToolViewMixin<T extends StatefulWidget> on State<T>, ToolResultHandler<T> {
  CancelToken? _cancelToken;

  PdfBloc get pdfBloc => BlocProvider.of<PdfBloc>(context);

  /// Clears leftover [HttpState]s for [keys] after the first frame so a freshly
  /// opened screen never reacts to a previous run's success/error.
  void resetToolState(List<String> keys) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) pdfBloc.add(ResetHttpStateEvent(keys: keys));
    });
  }

  /// Builds and dispatches an event with a fresh [CancelToken] so the in-flight
  /// request can be cancelled from the overlay.
  void runTool(PdfEvent Function(CancelToken cancelToken) build) {
    _cancelToken = CancelToken();
    pdfBloc.add(build(_cancelToken!));
  }

  /// Cancels the current request, if any.
  void cancelTool() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('cancelled-by-user');
    }
  }

  /// Standard reaction to a tool's [HttpState] change. On success it shows the
  /// rate-aware success message and either runs [onDone] or navigates to the
  /// PDF preview of the saved file. On error it shows a snackbar.
  void handleToolState(
    HttpState? s, {
    required String successMessage,
    bool navigateToPreview = true,
    void Function(File savedFile)? onDone,
    bool showInterstitial = true,
  }) {
    if (s == null) return;
    if (s.done == true) {
      // A paid tool debited credits server-side — refresh the balance shown in the UI.
      CreditService().refreshBalance();
      final saved = s.extras?['savedFile'];
      onToolSuccess(successMessage, output: saved is File ? saved : null);
      if (saved is File) {
        if (onDone != null) {
          onDone(saved);
        } else if (navigateToPreview) {
          GoRouter.of(context).pushNamed(
            AppRoutes.pdfFilePreviewRoute.name,
            pathParameters: {'pdfFilePath': saved.path},
            queryParameters: const {'from': 'tool'},
          );
        }
      }
      // Shown *after* the result is on screen. Dispatched first, the interstitial covered the
      // confirmation for most of the snackbar's four seconds, so the one affordance that led
      // to the next tool expired behind an ad.
      if (showInterstitial) AdsSingleton().dispatch(ShowInterstitialAd());
    } else if (s.error != null) {
      // Keyed off the 402 status rather than searching the message for "credit", which
      // broke as soon as the server reworded anything.
      final isCredit = s.isOutOfCredits;
      NotificationService.showSnackbar(
        text: s.error!,
        color: Colors.red,
        action: isCredit
            ? SnackBarAction(
                label: L10n.current.gateGetCredits,
                onPressed: () =>
                    GoRouter.of(context).pushNamed(AppRoutes.creditsRoute.name),
              )
            : null,
      );
    }
  }

  /// The processing overlay for [s], with Cancel wired to the active request.
  Widget processingOverlay(HttpState? s, {String? label}) {
    return ProcessingOverlay(
      httpState: s,
      label: label,
      onCancel: (_cancelToken != null && !_cancelToken!.isCancelled) ? cancelTool : null,
    );
  }
}
