import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/singletons/CreditService.dart';

/// Confirm-spend gate for paid tools.
///
/// Free tools (cost 0 / unpriced) run immediately. Paid tools first show a short
/// dialog with the price and the current balance; the tool proceeds only on confirm.
/// If the balance is too low, the dialog routes the user to the Credits screen instead.
/// (The server still enforces the real charge — this is a friendly heads-up, not the
/// security boundary.)
class CreditGate {
  CreditGate._();

  static Future<void> run(
    BuildContext context, {
    required String? creditToolId,
    required String toolName,
    required VoidCallback proceed,
  }) async {
    final cost = creditToolId == null ? 0 : CreditService().costFor(creditToolId);
    if (cost <= 0) {
      proceed();
      return;
    }

    final balance = CreditService().balance;
    final enough = balance >= cost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(toolName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.toll, size: 20),
                const SizedBox(width: 8),
                Text('Uses $cost credit${cost > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Your balance: $balance'),
            if (!enough) ...[
              const SizedBox(height: 8),
              Text('Not enough credits for this tool.',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          if (!enough)
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop(false);
                GoRouter.of(context).pushNamed(AppRoutes.creditsRoute.name);
              },
              child: const Text('Get credits'),
            )
          else
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Use $cost'),
            ),
        ],
      ),
    );

    if (confirmed == true) proceed();
  }
}
