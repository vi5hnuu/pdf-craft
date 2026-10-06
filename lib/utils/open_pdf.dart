import 'dart:io';

import 'package:flutter/material.dart' show Colors;
import 'package:pdfx/pdfx.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/logger_singleton.dart';
import 'package:pdf_craft/singletons/notification_service.dart';

/// Opens [file] for on-device page work, and says so when it cannot be read.
///
/// Every tool that needs a page count used to do this inline and end in `catch (_) {}`. A
/// password-protected or damaged PDF therefore left the screen sitting at zero pages with no
/// error and no explanation: the page picker was simply empty and the tool looked broken.
///
/// Returns null when the document could not be opened; the caller just keeps its own empty
/// state, because the user has already been told why.
Future<PdfDocument?> openPdfOrReport(File file) async {
  try {
    return await PdfDocument.openFile(file.path);
  } catch (e, st) {
    LoggerSingleton().logger.w('Could not open ${file.path}: $e', stackTrace: st);
    NotificationService.showSnackbar(
      text: _isPasswordProtected(e)
          ? L10n.current.errPdfPasswordProtected
          : L10n.current.errPdfUnreadable,
      color: Colors.red,
    );
    return null;
  }
}

/// Pdfium reports a wrong/missing password through the message rather than a typed error, so
/// this is a text match by necessity. Guessing wrong only costs the user a less specific
/// message, never a wrong outcome.
bool _isPasswordProtected(Object e) {
  final m = e.toString().toLowerCase();
  return m.contains('password') || m.contains('encrypt');
}
