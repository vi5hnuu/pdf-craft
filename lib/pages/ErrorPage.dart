import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/utils/StoragePermissions.dart';

enum ErrorReason { STORAGE_PERMISSION_DENIED }

class Errorpage extends StatefulWidget {
  final ErrorReason? reason;

  const Errorpage({super.key, this.reason});

  @override
  State<Errorpage> createState() => _ErrorpageState();
}

class _ErrorpageState extends State<Errorpage> {
  bool _requesting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (widget.reason == ErrorReason.STORAGE_PERMISSION_DENIED) {
      return _buildPermissionScreen(theme, primary);
    }
    return _buildGenericError(theme);
  }

  Widget _buildPermissionScreen(ThemeData theme, Color primary) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LottieBuilder.asset(
                  'assets/lottie/error.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'Storage Permission Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'PDF Craft needs access to your files to manage, view, and process your documents. Without this permission, the app cannot function.',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _requesting ? null : _requestPermission,
                  icon: _requesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(_requesting ? 'Requesting...' : 'Grant Permission'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenericError(ThemeData theme) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LottieBuilder.asset(
                  'assets/lottie/error.json',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'Something Went Wrong',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'An unexpected error occurred. Please try going back.',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => GoRouter.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final granted = await StoragePermissions.requestStoragePermissions();
      if (!mounted) return;
      if (granted) {
        GoRouter.of(context).goNamed(AppRoutes.filesRoute.name);
      } else {
        NotificationService.showSnackbar(
            text: 'Permission denied', color: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }
}
