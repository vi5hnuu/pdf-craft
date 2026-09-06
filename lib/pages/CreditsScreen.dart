import 'package:flutter/material.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/PurchaseService.dart';
import 'package:pdf_craft/singletons/RewardedAdManager.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';
import 'package:pdf_craft/theme/app_radius.dart';

/// A credit pack the app sells. [defaultPrice] is a placeholder shown until the real
/// localized price is fetched from Google Play (once the product is created there).
class _Pack {
  final String id;
  final int credits;
  final String defaultPrice;
  const _Pack(this.id, this.credits, this.defaultPrice);
}

/// Credit wallet: shows the balance and the ways to top up — claim the daily free
/// allowance, watch a rewarded ad, or buy a credit pack (Google Play INAPP). Purchases
/// are verified server-side (the token is redeemed via [CreditService.redeemPurchase]).
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  /// The packs the app offers. Ids must match the Play Console INAPP product ids.
  static const _packs = <_Pack>[
    _Pack('pdfcraft_credits_10', 10, '₹49'),
    _Pack('pdfcraft_credits_30', 30, '₹129'),
    _Pack('pdfcraft_credits_60', 60, '₹229'),
  ];

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Ensure IAP is initialized (no-op if already) and refresh balance + costs.
    PurchaseService().init();
    CreditService().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => CreditService().load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => CreditService().load(),
        child: AnimatedBuilder(
          animation: Listenable.merge([CreditService(), PurchaseService()]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
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
              ..._packs.map((p) => _packTile(theme, p)),
              if (PurchaseService().initialized && !PurchaseService().available)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'In-app purchases aren’t available on this device yet.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(AppRadius.surface),
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

  Widget _packTile(ThemeData theme, _Pack pack) {
    final product = PurchaseService().product(pack.id); // non-null once the Play product exists
    final available = product != null;
    final priceLabel = product?.price ?? pack.defaultPrice;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(Icons.toll_outlined, color: theme.colorScheme.primary),
        title: Text('${pack.credits} credits'),
        subtitle: Text(available ? 'One-time purchase' : 'Available soon'),
        trailing: available
            ? FilledButton(
                onPressed: _busy ? null : () => _buy(pack.id),
                child: Text(priceLabel),
              )
            : OutlinedButton(
                onPressed: null,
                child: Text(priceLabel),
              ),
      ),
    );
  }

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
      // The reward is granted by Google's verification callback to the API, not by us,
      // so this waits for the balance to move rather than asking for credits.
      onRewardEarned: () async {
        try {
          final granted = await CreditService().awaitRewardedCredits();
          if (granted > 0) {
            NotificationService.showSnackbar(
                text: 'Earned +$granted credits!', color: Colors.green);
          } else {
            NotificationService.showSnackbar(
                text: 'Thanks for watching — your credits will appear shortly.',
                color: Colors.orange);
          }
        } catch (_) {
          NotificationService.showSnackbar(
              text: "Couldn't confirm your credits. Pull to refresh in a moment.",
              color: Colors.orange);
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

  Future<void> _buy(String productId) async {
    setState(() => _busy = true);
    try {
      // The result (credit grant) is handled globally by PurchaseService via the purchase
      // stream, so it completes even if the user leaves this screen.
      await PurchaseService().buy(productId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
