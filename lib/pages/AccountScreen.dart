import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/auth/AuthUser.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/auth/AuthApi.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

/// The user's account hub. Shows who they are, a **clear path to verify their e-mail**
/// when it isn't confirmed yet (resend + recheck), their credits, and account actions
/// (change password, sign out, delete). Guests see a prompt to create an account.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pick up a verification that may have happened since we last loaded.
    AuthService().refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AnimatedBuilder(
        animation: AuthService(),
        builder: (context, _) {
          final user = AuthService().user;
          if (user == null || user.isGuest) return _guestBody(context);
          return _accountBody(context, user);
        },
      ),
    );
  }

  // ── Guest ─────────────────────────────────────────────────────────────────────

  Widget _guestBody(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 12),
        Icon(Icons.account_circle_outlined, size: 88, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('You’re using PDF Craft as a guest',
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Create a free account to keep your credits safe and sync across devices.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => context.pushNamed(AppRoutes.authRoute.name),
          child: const Text('Create account or sign in'),
        ),
        const SizedBox(height: 24),
        _creditsTile(context),
      ],
    );
  }

  // ── Signed-in ───────────────────────────────────────────────────────────────

  Widget _accountBody(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);
    final name = [user.firstName, user.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        // Header.
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                _initials(name, user.email),
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? (user.username ?? 'Your account') : name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  if (user.email != null)
                    Text(user.email!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  _providerChip(theme, user),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Verification — the key UX: how to verify, always reachable while unverified.
        if (!user.enabled) _verifyCard(context, user) else _verifiedTile(theme),
        const SizedBox(height: 16),

        _creditsTile(context),
        const SizedBox(height: 16),

        // Actions.
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Edit profile'),
              subtitle: const Text('Change your name'),
              onTap: _busy ? null : () => _editProfile(user),
            ),
            const Divider(height: 1, indent: 56),
            if (user.authProvider == 'LOCAL')
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: const Text('Change password'),
                onTap: _busy ? null : _changePassword,
              ),
            if (user.authProvider == 'LOCAL') const Divider(height: 1, indent: 56),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: _busy ? null : _signOut,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              title: Text('Delete account',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: _busy ? null : _deleteAccount,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _verifyCard(BuildContext context, AuthUser user) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.mark_email_unread_outlined, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Verify your email',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'We sent a link to ${user.email ?? 'your email'}. Open it, tap “Verify email”, '
              'then come back and tap “I’ve verified”. Check spam if you don’t see it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resend(user.email),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Resend'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _recheck,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text("I've verified"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifiedTile(ThemeData theme) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.verified_outlined, color: Colors.green.shade600),
        title: const Text('Email verified'),
        subtitle: const Text('Your account is fully set up.'),
      ),
    );
  }

  Widget _creditsTile(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: AnimatedBuilder(
        animation: CreditService(),
        builder: (context, _) => ListTile(
          leading: Icon(Icons.toll, color: theme.colorScheme.primary),
          title: const Text('Credits'),
          subtitle: Text('${CreditService().balance} available'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoutes.creditsRoute.name),
        ),
      ),
    );
  }

  Widget _providerChip(ThemeData theme, AuthUser user) {
    final label = switch (user.authProvider) {
      'GOOGLE' => 'Google account',
      'LOCAL' => 'Email account',
      _ => user.accountType,
    };
    return Chip(
      label: Text(label, style: theme.textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  String _initials(String name, String? email) {
    if (name.isNotEmpty) {
      final parts = name.trim().split(RegExp(r'\s+'));
      return parts.length >= 2
          ? (parts.first[0] + parts.last[0]).toUpperCase()
          : parts.first[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  // ── actions ──────────────────────────────────────────────────────────────────

  Future<void> _resend(String? email) async {
    if (email == null) return;
    setState(() => _busy = true);
    try {
      await AuthService().reVerify(email);
      NotificationService.showSnackbar(
          text: 'Verification email sent to $email.', color: Colors.green);
    } on AuthException catch (e) {
      NotificationService.showSnackbar(text: e.message, color: Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recheck() async {
    setState(() => _busy = true);
    try {
      final verified = await AuthService().refreshProfile();
      NotificationService.showSnackbar(
        text: verified
            ? 'Email verified — you’re all set!'
            : 'Not verified yet. Open the link in your email, then try again.',
        color: verified ? Colors.green : Colors.orange,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editProfile(AuthUser user) async {
    final firstC = TextEditingController(text: user.firstName ?? '');
    final lastC = TextEditingController(text: user.lastName ?? '');
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Edit profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'First name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastC,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      );
      if (ok != true) return;
      setState(() => _busy = true);
      try {
        await AuthService().updateProfile(
            firstName: firstC.text.trim(), lastName: lastC.text.trim());
        NotificationService.showSnackbar(text: 'Profile updated.', color: Colors.green);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } finally {
      firstC.dispose();
      lastC.dispose();
    }
  }

  Future<void> _changePassword() async {
    final oldC = TextEditingController();
    final newC = TextEditingController();
    try {
      var obscure = true;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setInner) => AlertDialog(
            title: const Text('Change password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldC,
                  obscureText: obscure,
                  decoration: const InputDecoration(labelText: 'Current password'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newC,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'New password (min 8)',
                    suffixIcon: IconButton(
                      icon: Icon(obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setInner(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Update')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      if (newC.text.length < 8) {
        NotificationService.showSnackbar(
            text: 'New password must be at least 8 characters.', color: Colors.red);
        return;
      }
      setState(() => _busy = true);
      try {
        await AuthService().changePassword(oldC.text, newC.text);
        NotificationService.showSnackbar(text: 'Password updated.', color: Colors.green);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } finally {
      oldC.dispose();
      newC.dispose();
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await AuthService().logout();
      await CreditService().load();
      NotificationService.showSnackbar(text: 'Signed out.', color: Colors.orange);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'This permanently deletes your account. Your credits and profile cannot be recovered. '
            'You’ll continue as a guest.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await AuthService().deleteAccount();
      await CreditService().load();
      NotificationService.showSnackbar(text: 'Account deleted.', color: Colors.orange);
    } on AuthException catch (e) {
      NotificationService.showSnackbar(text: e.message, color: Colors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
