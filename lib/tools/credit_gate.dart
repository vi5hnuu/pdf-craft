import 'dart:io';

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
    /// The files about to be processed, when they are already known. Supplying them lets
    /// the dialog quote the size surcharge the server will actually apply instead of the
    /// bare base price.
    List<File>? files,
  }) async {
    if (creditToolId == null) {
      proceed();
      return;
    }

    final int sizeBytes = _totalBytes(files);
    final cost = sizeBytes > 0
        ? CreditService().costForSize(creditToolId, sizeBytes)
        : CreditService().costFor(creditToolId);
    // When the files are not known yet (the picker has not run), the price can still grow
    // with size, so the dialog says "from N" rather than stating a figure it cannot promise.
    final approximate = sizeBytes == 0 && CreditService().hasSizeSurcharge(creditToolId);

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
                Text(
                    approximate
                        ? 'Uses from $cost credit${cost > 1 ? 's' : ''}'
                        : 'Uses $cost credit${cost > 1 ? 's' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (approximate) ...[
              const SizedBox(height: 4),
              Text('Larger files may cost more.',
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
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

  /// Total size of the selected files, or 0 when they are not known yet.
  static int _totalBytes(List<File>? files) {
    if (files == null || files.isEmpty) return 0;
    var total = 0;
    for (final file in files) {
      try {
        total += file.lengthSync();
      } catch (_) {
        // Unreadable here just means we quote the base price; the server is authoritative.
      }
    }
    return total;
  }
}
