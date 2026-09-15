import 'package:flutter/material.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// A storage location row on the Files tab (Internal Storage, Downloads, …).
///
/// Uses a Material icon. It used to render four small SVG files, which was the app's only
/// reason to ship flutter_svg (plus its vector-graphics/XML parsing dependencies) — a few
/// hundred KB of APK size for four icons.
class StorageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  const StorageTile({
    super.key,
    this.onTap,
    required this.icon,
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.surface)),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.surface),
          ),
          child: Icon(icon, color: primary, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        trailing: trailing,
      ),
    );
  }
}
