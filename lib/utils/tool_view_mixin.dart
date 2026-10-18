import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/models/http_state.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/ads_singleton.dart';
import 'package:pdf_craft/singletons/crash_reporter.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/singletons/rate_app_service.dart';
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
    final event = build(_cancelToken!);
    // A breadcrumb, so a crash report says which tool the user was running. CrashReporter.log
    // was written for this and had no callers at all, which left every report with no trail
    // leading up to it. The event's runtime type is safe to disclose — it is our own class
    // name, never a filename or anything the user typed.
    CrashReporter().log('runTool ${event.runtimeType}');
    pdfBloc.add(event);
  }

  /// Reads [source] for upload, or says why it cannot be read and returns null.
  ///
  /// Tool screens used to call `MultipartFile.fromFile` straight from a `void async` handler
  /// with no try. It stats the path and throws if the file has been moved, renamed, deleted or
  /// is simply unreadable, and that throw escaped all the way to runZonedGuarded — so the user
  /// tapped Run and *nothing happened at all*: no overlay, no error, no explanation. It is
  /// reachable rather than theoretical, because UploadLimits deliberately counts an unreadable
  /// file as 0 bytes, so a file that has gone away sails through the size check.
  ///
  /// Returning null rather than throwing lets the caller simply `return` and leave the screen
  /// as it was.
  Future<MultipartFile?> readForUpload(File source) async {
    try {
      if (!await source.exists()) {
        throw PathNotFoundException(source.path, const OSError('No such file'));
      }
      return await MultipartFile.fromFile(source.path);
    } catch (e) {
      LoggerSingleton().logger.w('Upload source unreadable: ${source.path} ($e)');
      if (mounted) {
        NotificationService.showSnackbar(text: L10n.current.errFileGone, kind: SnackKind.error);
      }
      return null;
    }
  }

  /// Reads every file in [sources] for upload, or returns null if any cannot be read.
  ///
  /// All-or-nothing on purpose: silently dropping one file of a merge would produce a result
  /// the user did not ask for and could not tell was incomplete.
  Future<List<MultipartFile>?> readAllForUpload(Iterable<File> sources) async {
    final parts = <MultipartFile>[];
    for (final source in sources) {
      final part = await readForUpload(source);
      if (part == null) return null;
      parts.add(part);
    }
    return parts;
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
    /// Set false when [onDone] navigates to the preview itself — the preview carries its own
    /// "use in another tool" button, and offering the same thing in the snackbar makes it
    /// long-lived enough to follow the user onto the next screen.
    bool? offerNextTool,
  }) {
    if (s == null) return;
    // Only react to work *this* screen started. 61 HttpStates keys are shared across tools —
    // five screens share `reorderPdf` alone — so a tool still mounted beneath another (which is
    // exactly what "use in another tool" creates) would otherwise handle the second screen's
    // result as if it were its own: two previews pushed, two snackbars, two interstitials.
    // The cancel token is set by runTool, so it is precisely "did I dispatch this?".
    if (_cancelToken == null) return;
    if (s.done == true || s.error != null) {
      // Consumed. A late duplicate delivery of the same state must not fire everything twice.
      _cancelToken = null;
    }
    if (s.done == true) {
      // A paid tool debited credits server-side — refresh the balance shown in the UI.
      CreditService().refreshBalance();
      final saved = s.extras?['savedFile'];
      // The preview carries its own "use in another tool" button, so the snackbar only needs to
      // offer one when the user is not being taken there.
      final goingToPreview = saved is File && onDone == null && navigateToPreview;
      onToolSuccess(successMessage,
          output: saved is File ? saved : null,
          offerNextTool: offerNextTool ?? !goingToPreview);
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
      // confirmation for most of its lifetime.
      if (showInterstitial) AdsSingleton().dispatch(ShowInterstitialAd());
    } else if (s.error != null) {
      // Something of the user's just failed. Whatever else happens this session, it is not the
      // moment to ask them to rate the app.
      RateAppService().noteError();
      // Keyed off the 402 status rather than searching the message for "credit", which
      // broke as soon as the server reworded anything.
      final isCredit = s.isOutOfCredits;
      NotificationService.showSnackbar(
        text: s.error!,
        kind: SnackKind.error,
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

  @override
  void dispose() {
    // Leaving the screen used to leave the upload running: cancelTool had exactly one caller,
    // the overlay's Cancel button, so backing out mid-upload left a request of up to the
    // 50 MB limit streaming with nothing left to receive the result.
    cancelTool();
    super.dispose();
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
