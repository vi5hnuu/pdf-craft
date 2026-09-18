import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf_craft/l10n/l10n.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/widgets/app_logo.dart';
import 'package:pdf_craft/theme/app_radius.dart';
import 'package:pdf_craft/utils/constants.dart';
import 'package:pdf_craft/services/auth/auth_api.dart';
import 'package:pdf_craft/singletons/auth_service.dart';
import 'package:pdf_craft/singletons/credit_service.dart';
import 'package:pdf_craft/singletons/notification_service.dart';

/// Sign-in / create-account screen. The app is guest-first, so "Create account"
/// converts the current guest (keeping their credits); "Sign in" switches to an
/// existing account. Google sign-in is offered for one-tap access.
class AuthScreen extends StatefulWidget {
  /// Start in create-account mode (default) or sign-in mode (e.g. from a session-expired prompt).
  final bool initialCreateMode;
  const AuthScreen({super.key, this.initialCreateMode = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  late bool _createMode = widget.initialCreateMode;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // A labelled way out rather than a bare X: the app is guest-first, so leaving here is a
        // legitimate choice and should read like one.
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: L10n.of(context).authContinueAsGuest,
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The app's own mark, not a generic trophy in a circle. Every other surface in
              // this app is squared to AppRadius.surface (2) on purpose — "that reads as soft
              // and inconsistent rather than like a tool" — and a 72px circle was the softest
              // shape in the product sitting on its most important screen.
              const Center(child: AppLogo(width: 132)),
              const SizedBox(height: 24),

              // One control, two modes. This used to be a text link below the fold, so the
              // screen always opened in create-account mode and returning users had to hunt.
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: true, label: Text(L10n.of(context).authModeCreate)),
                  ButtonSegment(value: false, label: Text(L10n.of(context).authModeSignIn)),
                ],
                selected: {_createMode},
                showSelectedIcon: false,
                onSelectionChanged:
                    _busy ? null : (sel) => setState(() => _createMode = sel.first),
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.surface))),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                _createMode
                    ? L10n.of(context).authCreateTitle
                    : L10n.of(context).authSignInTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _createMode
                    ? L10n.of(context).authCreateSubtitle
                    : L10n.of(context).authSignInSubtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // Google first, at full weight. It is one tap against an email, a password and a
              // verification mail, so burying it under the form put the slowest path first.
              _googleButton(theme, cs),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Divider(color: theme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(L10n.of(context).authOr,
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ),
                Expanded(child: Divider(color: theme.dividerColor)),
              ]),
              const SizedBox(height: 20),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_createMode) ...[
                      TextFormField(
                        controller: _name,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: L10n.of(context).authNameOptional,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: L10n.of(context).authEmail,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || !v.contains('@') || v.trim().length < 3)
                          ? L10n.of(context).authInvalidEmail
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _busy ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: L10n.of(context).authPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          tooltip: L10n.of(context).authPassword,
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.length < 8) ? L10n.of(context).authPasswordMin : null,
                    ),
                    if (!_createMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _forgotPassword,
                          child: Text(L10n.of(context).authForgotPassword),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: _createMode ? 20 : 8),

              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.surface)),
                ),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Text(_createMode
                        ? L10n.of(context).authCreateAccount
                        : L10n.of(context).authSignIn),
              ),

              // Why bother having an account at all. The old screen asserted the benefit once,
              // in grey, as a subtitle; a guest had no reason to read it.
              if (_createMode) ...[
                const SizedBox(height: 24),
                _benefit(theme, cs, Icons.savings_outlined, L10n.of(context).authBenefitCredits),
                _benefit(theme, cs, Icons.devices_outlined, L10n.of(context).authBenefitSync),
                _benefit(
                    theme, cs, Icons.restore_outlined, L10n.of(context).authBenefitRestore),
              ],

              const SizedBox(height: 20),
              Text(
                L10n.of(context).authGuestNote,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              if (_createMode) ...[
                const SizedBox(height: 12),
                _legalDisclaimer(theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Google's button, given the same height and squared corners as the primary action so the
  /// two read as equal choices rather than a button and an afterthought.
  Widget _googleButton(ThemeData theme, ColorScheme cs) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: theme.dividerColor),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.surface)),
        ),
        onPressed: _busy ? null : _google,
        // Without a busy state this button looked idle while the account picker was opening,
        // which on a slow device reads as "nothing happened" and invites a second tap.
        icon: _busy
            ? const SizedBox(
                height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2))
            : const FaIcon(FontAwesomeIcons.google, size: 18),
        label: Text(L10n.of(context).authContinueGoogle,
            style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  Widget _benefit(ThemeData theme, ColorScheme cs, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
        ]),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (_createMode) {
        await AuthService().convertGuest(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
        if (!mounted) return;
        NotificationService.showSnackbar(
            text: L10n.current.authAccountCreated, color: Colors.green);
        // Land on the account hub so the "verify your email" path is front and centre.
        context.pushReplacementNamed(AppRoutes.accountRoute.name);
      } else {
        // Signing in switches to an existing account. Warn a guest who'd leave credits behind
        // (only "Create account" carries a guest's credits over).
        if (AuthService().isGuest && CreditService().balance > 0) {
          final go = await _confirmSwitch(CreditService().balance);
          if (go != true) return;
        }
        await AuthService().login(_email.text.trim(), _password.text);
        await CreditService().load(); // switched account → reload its balance
        _done(L10n.current.authSignedIn);
      }
    } on AuthException catch (e) {
      // Blocked because the e-mail isn't verified → give a real way to verify, not a dead-end toast.
      if (!_createMode && _isVerifyError(e)) {
        if (mounted) await _showVerifyPrompt(_email.text.trim());
      } else {
        _fail(e.message);
      }
    } catch (e) {
      _fail(L10n.current.authSomethingWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _isVerifyError(AuthException e) =>
      e.statusCode == 403 && e.message.toLowerCase().contains('verif');

  /// Shown when sign-in is blocked by an unverified e-mail: explains how to verify and
  /// lets the user resend the link right here (the only place they can act on it).
  Future<void> _showVerifyPrompt(String email) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_unread_outlined, size: 40),
        title: Text(L10n.of(ctx).authVerifyFirstTitle),
        content: Text(L10n.of(ctx)
            .authVerifyFirstBody(email.isEmpty ? L10n.of(ctx).yourEmail : email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(L10n.of(ctx).close),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined, size: 18),
            label: Text(L10n.of(ctx).authResendLink),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final msg = await AuthService().reVerify(email);
                NotificationService.showSnackbar(text: msg, color: Colors.green);
              } on AuthException catch (e) {
                NotificationService.showSnackbar(text: e.message, color: Colors.red);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _google() async {
    FocusScope.of(context).unfocus();
    // Same warning the password path already gave. Google sign-in switches to the Google
    // account exactly as signing in does, so a guest's credits are left behind either way —
    // but this path asked nothing and simply took them, which is the worse version of the two
    // because it is also the faster one to tap.
    if (AuthService().isGuest && CreditService().balance > 0) {
      final go = await _confirmSwitch(CreditService().balance);
      if (go != true) return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await AuthService().signInWithGoogle();
      await CreditService().load();
      _done(L10n.current.authSignedInGoogle);
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail(L10n.current.authGoogleFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirms a sign-in that would leave a guest's credits behind.
  Future<bool?> _confirmSwitch(int credits) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.of(ctx).authSwitchTitle),
        content: Text(
            '${L10n.of(ctx).authSwitchCredits(credits)} ${L10n.of(ctx).authSwitchBody}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(L10n.of(ctx).cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(L10n.of(ctx).authSignInAnyway)),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _fail(L10n.current.authEnterEmailFirst);
      return;
    }
    try {
      await AuthService().forgotPassword(email);
      if (!mounted) return;
      // Explain the next step — the reset itself completes via the emailed link.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, size: 40),
          title: Text(L10n.of(ctx).authCheckEmailTitle),
          content: Text(L10n.of(ctx).authResetSentBody(email)),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.of(ctx).gotIt)),
          ],
        ),
      );
    } catch (e) {
      _fail(L10n.current.authResetFailed);
    }
  }

  Widget _legalDisclaimer(ThemeData theme) {
    final base = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final link = base?.copyWith(
        color: theme.colorScheme.primary, decoration: TextDecoration.underline);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Split into pieces so each language can order the sentence naturally around the links.
        Text(L10n.of(context).authLegalPrefix, style: base),
        GestureDetector(
            onTap: () => _openUrl(Constants.termsUrl),
            child: Text(L10n.of(context).authLegalTerms, style: link)),
        Text(L10n.of(context).authLegalAnd, style: base),
        GestureDetector(
            onTap: () => _openUrl(Constants.privacyUrl),
            child: Text(L10n.of(context).authLegalPrivacy, style: link)),
        Text(L10n.of(context).authLegalSuffix, style: base),
      ],
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _done(String message) {
    if (!mounted) return;
    NotificationService.showSnackbar(text: message, color: Colors.green);
    Navigator.of(context).pop();
  }

  void _fail(String message) {
    NotificationService.showSnackbar(text: message, color: Colors.red);
  }
}
