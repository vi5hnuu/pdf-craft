import 'package:flutter/material.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/singletons/app_config_service.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown instead of the app when the running build is below the supported minimum.
///
/// Deliberately a dead end: there is no back, no dismiss and nothing else to tap. A build is only
/// ever refused because it would otherwise do something wrong — talk to an API whose contract it
/// no longer matches, or carry a bug worth stopping — so letting someone past defeats the point.
class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = AppConfigService().config;
    final message = config.updateMessage?.trim();

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text(L10n.of(context).updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    // The server may supply its own wording for the specific reason.
                    message != null && message.isNotEmpty
                        ? message
                        : L10n.of(context).updateRequiredBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: Text(L10n.of(context).updateNowAction),
                      onPressed: () => openStoreListing(config.storeUrl),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the store listing, falling back to this app's own page when the server named none.
Future<void> openStoreListing(String? storeUrl) async {
  final url = (storeUrl != null && storeUrl.trim().isNotEmpty)
      ? storeUrl.trim()
      : 'https://play.google.com/store/apps/details?id=${Constants.androidPackageName}';
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
