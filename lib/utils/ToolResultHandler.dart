import 'package:flutter/material.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/singletons/RateAppService.dart';

/// Shared helpers for tool view success/error/offline handling.
/// Shows the rate-app dialog after N successful completions.
mixin ToolResultHandler<T extends StatefulWidget> on State<T> {

  /// Call on successful tool completion.
  void onToolSuccess(String message) async {
    NotificationService.showSnackbar(text: message, color: Colors.green);
    final shouldRate = await RateAppService().recordSuccess();
    if (shouldRate && mounted) _showRateDialog();
  }

  void _showRateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enjoying PDF Craft?'),
        content: const Text(
          'You\'ve processed several files! If you find this app useful, please take a moment to rate it. It helps a lot.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              RateAppService().markRated(); // "not now" = mark rated to avoid spam
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              await RateAppService().markRated();
              await RateAppService().openPlayStore();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }
}
