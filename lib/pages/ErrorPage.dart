import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
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
  // Once the OS reports a permanent denial, the in-app request no longer shows a
  // system dialog — the user must enable it from Settings, so we switch the CTA.
  bool _permanentlyDenied = false;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branded hero — a folder + lock badge conveys "your files, kept private".
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary.withValues(alpha: 0.18), primary.withValues(alpha: 0.06)],
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.folder_rounded, size: 52, color: primary),
                      Positioned(
                        right: 26,
                        bottom: 28,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lock_rounded, size: 16, color: primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Allow file access',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'PDF Craft works with the PDFs and images already on your device. '
                  'Grant file access so you can browse, open and save your documents.',
                  style: TextStyle(
                    fontSize: 15,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // What the permission unlocks.
                _benefit(theme, primary, Icons.folder_open_outlined, 'Browse & open your PDFs and images'),
                _benefit(theme, primary, Icons.save_alt_outlined, 'Save tool results back to your storage'),
                _benefit(theme, primary, Icons.shield_outlined, 'Files stay on your device until you use a tool'),
                if (_permanentlyDenied) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Icon(Icons.info_outline, size: 18, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Access was turned off. Enable “All files access” (or Storage) for '
                          'PDF Craft in system Settings.',
                          style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _requesting ? null : (_permanentlyDenied ? _openSettings : _requestPermission),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _requesting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_permanentlyDenied ? Icons.settings_outlined : Icons.check_circle_outline),
                    label: Text(
                      _requesting
                          ? 'Requesting…'
                          : (_permanentlyDenied ? 'Open Settings' : 'Allow access'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(ThemeData theme, Color primary, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
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
        // If the OS won't show the dialog anymore, guide the user to Settings.
        final permanentlyDenied = await StoragePermissions.isPermanentlyDenied();
        if (!mounted) return;
        setState(() => _permanentlyDenied = permanentlyDenied);
        if (!permanentlyDenied) {
          NotificationService.showSnackbar(
              text: 'Permission denied', color: Colors.red);
        }
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    // Re-check on return; proceed if the user enabled it in Settings.
    final granted = await StoragePermissions.isStoragePermissionGranted();
    if (!mounted) return;
    if (granted) GoRouter.of(context).goNamed(AppRoutes.filesRoute.name);
  }
}
