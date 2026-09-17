import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/notification_service.dart';
import 'package:pdf_craft/widgets/next_tool_sheet.dart';

/// Shared success feedback for tool views.
///
/// The rate-app prompt is intentionally **not** handled here. MainScreen's app-wide PdfBloc
/// listener already records every tool success (including screens that don't use this mixin);
/// recording here as well counted each success twice and could stack two different rate dialogs.
mixin ToolResultHandler<T extends StatefulWidget> on State<T> {

  /// Call on successful tool completion.
  ///
  /// When the tool produced a file, the confirmation carries a way straight into the next tool.
  /// Without it the result was a dead end: continuing meant leaving the screen, opening the file
  /// browser and finding the output again by name.
  void onToolSuccess(String message, {File? output}) {
    NotificationService.showSnackbar(
      text: message,
      color: Colors.green,
      action: output == null
          ? null
          : SnackBarAction(
              label: L10n.current.useInAnotherTool,
              textColor: Colors.white,
              onPressed: () {
                if (mounted) NextToolSheet.show(context, output);
              },
            ),
    );
  }
}
