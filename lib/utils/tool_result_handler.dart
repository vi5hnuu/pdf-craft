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
  /// [offerNextTool] adds a shortcut into the next tool. Pass it only when the user is staying
  /// on this screen: when the tool navigates to the result preview, that screen already carries
  /// a permanent "use in another tool" button, so the same action in a snackbar is a duplicate —
  /// and a costly one. An action makes the snackbar long-lived, and the ScaffoldMessenger is
  /// app-wide, so it re-parents to each screen the user opens next and restarts its timer there.
  /// On device that read as a success toast that followed you around for minutes, covering the
  /// bottom of every screen including the primary button beneath it.
  void onToolSuccess(String message, {File? output, bool offerNextTool = false}) {
    NotificationService.showSnackbar(
      text: message,
      color: Colors.green,
      action: (output == null || !offerNextTool)
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
