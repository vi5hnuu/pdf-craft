import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf_craft/models/auth/auth_user.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/services/auth/auth_api.dart';
import 'package:pdf_craft/singletons/auth_service.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/notification_service.dart';

/// The user's account hub. Shows who they are, a **clear path to verify their e-mail**
/// when it isn't confirmed yet (resend + recheck), their credits, and account actions
/// (change password, sign out, delete). Guests see a prompt to create an account.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  /// Which action is running, or null. Not a bare `bool`: this screen used one to *disable* all
  /// six actions while any one of them worked, but never drew progress anywhere — so tapping
  /// "Resend" greyed the row out silently for the whole round trip and read as a dead control.
  /// Naming the action lets the spinner sit on the row the user actually tapped.
  String? _running;

  bool get _busy => _running != null;
  bool _isRunning(String action) => _running == action;

  static const _actionResend = 'resend';
  static const _actionRecheck = 'recheck';
  static const _actionProfile = 'profile';
  static const _actionPassword = 'password';
  static const _actionSignOut = 'signOut';
  static const _actionDelete = 'delete';

  /// Runs [body] under [action]'s spinner, releasing it however [body] ends.
  Future<void> _run(String action, Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _running = action);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  /// A row's leading slot: the spinner while this row is the one working, its icon otherwise.
  Widget _leading(String action, Widget icon) => _isRunning(action)
      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.2))
      : icon;

  @override
  void initState() {
    super.initState();
    // Pick up a verification that may have completed since we last loaded (full accounts only).
    if (AuthService().isSignedInFull) AuthService().refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).settingsSectionAccount)),
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
        Text(L10n.of(context).accountGuestTitle,
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          L10n.of(context).accountGuestBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () => context.pushNamed(AppRoutes.authRoute.name),
          child: Text(L10n.of(context).accountCreateOrSignIn),
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
                  Text(name.isEmpty ? (user.username ?? L10n.of(context).accountYourAccount) : name,
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
              // `enabled` is what actually greys a ListTile out; `onTap: null` alone leaves it at
              // full opacity, looking tappable while it swallows taps.
              enabled: !_busy,
              leading: _leading(_actionProfile, const Icon(Icons.badge_outlined)),
              title: Text(L10n.of(context).accountEditProfile),
              subtitle: Text(L10n.of(context).accountChangeName),
              onTap: _busy ? null : () => _editProfile(user),
            ),
            const Divider(height: 1, indent: 56),
            if (user.authProvider == 'LOCAL')
              ListTile(
                enabled: !_busy,
                leading: _leading(_actionPassword, const Icon(Icons.password_outlined)),
                title: Text(L10n.of(context).accountChangePassword),
                onTap: _busy ? null : _changePassword,
              ),
            if (user.authProvider == 'LOCAL') const Divider(height: 1, indent: 56),
            ListTile(
              enabled: !_busy,
              leading: _leading(_actionSignOut, const Icon(Icons.logout)),
              title: Text(L10n.of(context).signOut),
              onTap: _busy ? null : _signOut,
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              enabled: !_busy,
              leading: _leading(_actionDelete,
                  Icon(Icons.delete_outline, color: theme.colorScheme.error)),
              title: Text(L10n.of(context).accountDelete,
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
                child: Text(L10n.of(context).accountVerifyTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              L10n.of(context).accountVerifyBody(user.email ?? L10n.of(context).yourEmail),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resend(user.email),
                    icon: _isRunning(_actionResend)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 18),
                    label: Text(L10n.of(context).accountResend),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _recheck,
                    icon: _isRunning(_actionRecheck)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check, size: 18),
                    label: Text(L10n.of(context).accountIveVerified),
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
        title: Text(L10n.of(context).accountEmailVerified),
        subtitle: Text(L10n.of(context).accountFullySetUp),
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
          title: Text(L10n.of(context).credits),
          subtitle: Text(L10n.of(context).creditsAvailable(CreditService().balance)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed(AppRoutes.creditsRoute.name),
        ),
      ),
    );
  }

  Widget _providerChip(ThemeData theme, AuthUser user) {
    final label = switch (user.authProvider) {
      'GOOGLE' => L10n.of(context).accountGoogle,
      'LOCAL' => L10n.of(context).accountEmail,
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
    return _run(_actionResend, () async {
      try {
        await AuthService().reVerify(email);
        NotificationService.showSnackbar(
            text: L10n.current.accountVerificationSent(email), color: Colors.green);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      }
    });
  }

  Future<void> _recheck() => _run(_actionRecheck, () async {
    final verified = await AuthService().refreshProfile();
    NotificationService.showSnackbar(
      text: verified
          ? L10n.current.accountVerifiedAllSet
          : L10n.current.accountNotVerifiedYet,
      color: verified ? Colors.green : Colors.orange,
    );
  });

  Future<void> _editProfile(AuthUser user) async {
    // The dialog owns its controllers (see [_EditProfileDialog]): doing it here and disposing
    // after `showDialog` returns releases them while the route is still animating out, which is
    // the "TextEditingController was used after being disposed" crash.
    final name = await showDialog<({String first, String last})>(
      context: context,
      builder: (ctx) => _EditProfileDialog(
          firstName: user.firstName ?? '', lastName: user.lastName ?? ''),
    );
    if (name == null) return;
    return _run(_actionProfile, () async {
      try {
        await AuthService()
            .updateProfile(firstName: name.first, lastName: name.last);
        NotificationService.showSnackbar(
            text: L10n.current.accountProfileUpdated, color: Colors.green);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      }
    });
  }

  Future<void> _changePassword() async {
    final pair = await showDialog<({String current, String next})>(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
    if (pair == null) return;
    return _run(_actionPassword, () async {
      try {
        await AuthService().changePassword(pair.current, pair.next);
        NotificationService.showSnackbar(
            text: L10n.current.accountPasswordUpdated, color: Colors.green);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      }
    });
  }

  Future<void> _signOut() => _run(_actionSignOut, () async {
    await AuthService().logout();
    await CreditService().load();
    NotificationService.showSnackbar(text: L10n.current.accountSignedOut, color: Colors.orange);
  });

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).accountDeleteTitle),
        content: Text(L10n.of(ctx).accountDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(ctx).cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L10n.of(ctx).delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    return _run(_actionDelete, () async {
      try {
        await AuthService().deleteAccount();
        await CreditService().load();
        NotificationService.showSnackbar(text: L10n.current.accountDeleted, color: Colors.orange);
      } on AuthException catch (e) {
        NotificationService.showSnackbar(text: e.message, color: Colors.red);
      }
    });
  }
}

/// Asks for a first and last name. A widget rather than an inline `AlertDialog` so it can own its
/// controllers and dispose them in its own `dispose`, once the route is genuinely gone.
class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final _firstC = TextEditingController(text: widget.firstName);
  late final _lastC = TextEditingController(text: widget.lastName);

  @override
  void dispose() {
    _firstC.dispose();
    _lastC.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(
      context, (first: _firstC.text.trim(), last: _lastC.text.trim()));

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.accountEditProfile),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _firstC,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.firstName),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lastC,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: l.lastName),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _save, child: Text(l.actionSave)),
      ],
    );
  }
}

/// Asks for the current and new password. Owns its controllers, and — unlike the version this
/// replaced — validates the new password *before* closing: a too-short password used to dismiss
/// the dialog and then complain in a snackbar, throwing away both typed passwords.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentC = TextEditingController();
  final _nextC = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _currentC.dispose();
    _nextC.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, (current: _currentC.text, next: _nextC.text));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return AlertDialog(
      title: Text(l.accountChangePassword),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _currentC,
              obscureText: _obscure,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l.accountCurrentPassword),
              validator: (v) =>
                  (v == null || v.isEmpty) ? l.passwordRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nextC,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.accountNewPassword,
                // One toggle for both fields: they are always typed in the same sitting, and the
                // point of revealing is to compare what was typed.
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  tooltip: _obscure ? l.showPassword : l.hidePassword,
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 8) ? l.accountPasswordTooShort : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(l.update)),
      ],
    );
  }
}
