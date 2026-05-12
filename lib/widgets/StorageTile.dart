import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StorageTile extends StatelessWidget {
  final String leadingIconSvgPath;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  const StorageTile({
    super.key,
    this.onTap,
    required this.leadingIconSvgPath,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SvgPicture.asset(leadingIconSvgPath, fit: BoxFit.contain),
          ),
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
