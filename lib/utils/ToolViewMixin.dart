import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/HttpState.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/AdsSingleton.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/state/pdf-state/pdf_bloc.dart';
import 'package:pdf_craft/utils/ToolResultHandler.dart';
import 'package:pdf_craft/widgets/ProcessingOverlay.dart';

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
      if (showInterstitial) AdsSingleton().dispatch(ShowInterstitialAd());
      onToolSuccess(successMessage);
      final saved = s.extras?['savedFile'];
      if (saved is File) {
        if (onDone != null) {
          onDone(saved);
        } else if (navigateToPreview) {
          GoRouter.of(context).pushNamed(
            AppRoutes.pdfFilePreviewRoute.name,
            pathParameters: {'pdfFilePath': saved.path},
          );
        }
      }
    } else if (s.error != null) {
      NotificationService.showSnackbar(text: s.error!, color: Colors.red);
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
