import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// Compact credit-balance pill for app bars. Shows the live balance and opens the
/// Credits (earn/buy) screen when tapped. Rebuilds automatically as the balance changes.
class CreditBalanceChip extends StatelessWidget {
  const CreditBalanceChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: CreditService(),
      builder: (context, _) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        onTap: () => context.pushNamed(AppRoutes.creditsRoute.name),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.toll, size: 18, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(
                '${CreditService().balance}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.add, size: 16, color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
