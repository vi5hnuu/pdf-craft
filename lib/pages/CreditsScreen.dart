import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/RewardedAdManager.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

/// Credit wallet: shows the balance and the ways to top up — claim the daily free
/// allowance, watch a rewarded ad, or buy a credit pack (Google Play INAPP). Purchases
/// are verified server-side (the token is redeemed via [CreditService.redeemPurchase]).
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  /// Credit-pack products; must match the Play Console INAPP product ids.
  static const _productIds = <String>{
    'pdfcraft_credits_10',
    'pdfcraft_credits_30',
    'pdfcraft_credits_60',
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  List<ProductDetails> _products = [];
  bool _storeAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _initStore();
    CreditService().refreshBalance();
  }

  Future<void> _initStore() async {
    _storeAvailable = await _iap.isAvailable();
    if (_storeAvailable) {
      final resp = await _iap.queryProductDetails(_productIds);
      if (mounted) setState(() => _products = resp.productDetails);
      _sub = _iap.purchaseStream.listen(_onPurchaseUpdates, onError: (_) {});
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.status == PurchaseStatus.purchased || p.status == PurchaseStatus.restored) {
        try {
          await CreditService().redeemPurchase(
              p.verificationData.serverVerificationData, p.productID);
          if (mounted) {
            NotificationService.showSnackbar(text: 'Credits added!', color: Colors.green);
          }
        } catch (e) {
          if (mounted) {
            NotificationService.showSnackbar(
                text: 'Could not verify purchase. Contact support if charged.',
                color: Colors.red);
          }
        }
      }
      if (p.status == PurchaseStatus.error && mounted) {
        NotificationService.showSnackbar(text: 'Purchase failed.', color: Colors.red);
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Credits')),
      body: AnimatedBuilder(
        animation: CreditService(),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _balanceCard(theme),
            const SizedBox(height: 24),
            Text('Earn free credits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _earnTile(
              icon: Icons.calendar_today_outlined,
              title: 'Claim daily credits',
              subtitle: 'A few free credits every day',
              onTap: _claimDaily,
            ),
            _earnTile(
              icon: Icons.smart_display_outlined,
              title: 'Watch an ad',
              subtitle: 'Get credits for watching a short video',
              onTap: _watchAd,
            ),
            const SizedBox(height: 24),
            Text('Buy credits', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (!_storeAvailable)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('The store is unavailable right now. Please try again later.'),
              )
            else if (_products.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No credit packs available yet.'),
              )
            else
              ..._sortedProducts().map(_packTile),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primaryContainer],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.toll, color: theme.colorScheme.onPrimary, size: 40),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your balance',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary)),
              Text('${CreditService().balance} credits',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earnTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: _busy ? null : onTap,
      ),
    );
  }

  Widget _packTile(ProductDetails p) {
    final credits = _creditsFor(p.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.toll_outlined),
        title: Text('$credits credits'),
        subtitle: Text(p.title),
        trailing: FilledButton(
          onPressed: _busy ? null : () => _buy(p),
          child: Text(p.price),
        ),
      ),
    );
  }

  List<ProductDetails> _sortedProducts() {
    final list = [..._products];
    list.sort((a, b) => _creditsFor(a.id).compareTo(_creditsFor(b.id)));
    return list;
  }

  int _creditsFor(String productId) =>
      int.tryParse(productId.split('_').last) ?? 0;

  Future<void> _claimDaily() async {
    setState(() => _busy = true);
    try {
      final granted = await CreditService().claimDaily();
      NotificationService.showSnackbar(text: 'Claimed +$granted credits!', color: Colors.green);
    } catch (e) {
      NotificationService.showSnackbar(
          text: 'Already claimed today. Come back tomorrow.', color: Colors.orange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _watchAd() {
    setState(() => _busy = true);
    RewardedAdManager().show(
      onRewardEarned: () async {
        final key = 'rw-${DateTime.now().millisecondsSinceEpoch}';
        try {
          final granted = await CreditService().grantRewarded(key);
          NotificationService.showSnackbar(text: 'Earned +$granted credits!', color: Colors.green);
        } catch (e) {
          NotificationService.showSnackbar(
              text: "You've hit today's ad-credit limit.", color: Colors.orange);
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
      onUnavailable: () {
        if (mounted) setState(() => _busy = false);
        NotificationService.showSnackbar(
            text: 'No ad available right now. Try again shortly.', color: Colors.orange);
      },
    );
  }

  Future<void> _buy(ProductDetails product) async {
    setState(() => _busy = true);
    try {
      await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (e) {
      NotificationService.showSnackbar(text: 'Could not start purchase.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
