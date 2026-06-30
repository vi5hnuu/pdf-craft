import 'package:flutter/material.dart';
import 'package:pdf_craft/models/HttpState.dart';
import 'package:pdf_craft/widgets/ProcessingOverlay.dart';

/// Backwards-compatible wrapper kept so existing tool screens keep working.
///
/// The actual presentation now lives in [ProcessingOverlay] (branded card,
/// staged status, security note, optional cancel). Pass [label] for a
/// tool-specific verb and [onCancel] to surface a Cancel button.
///
/// Place as the last child of a Stack that covers the whole screen.
class LoadingOverlay extends StatelessWidget {
  final HttpState? httpState;
  final String? label;
  final VoidCallback? onCancel;

  const LoadingOverlay({super.key, required this.httpState, this.label, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return ProcessingOverlay(httpState: httpState, label: label, onCancel: onCancel);
  }
}
