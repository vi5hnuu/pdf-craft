import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf_craft/routes.dart';
import 'package:pdf_craft/utils/Constants.dart';
import 'package:pdf_craft/services/auth/AuthApi.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

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
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Close (keep using as guest).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                    ),
                  ),

                  // Hero.
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.workspace_premium_rounded,
                          size: 38, color: cs.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _createMode ? 'Create your account' : 'Welcome back',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _createMode
                        ? 'Keep your credits safe and sync across devices.'
                        : 'Sign in to your PDF Craft account.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),

                  // Form.
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
                            decoration: const InputDecoration(
                              labelText: 'Name (optional)',
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || !v.contains('@') || v.trim().length < 3)
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _busy ? null : _submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'At least 8 characters'
                              : null,
                        ),
                        if (!_createMode)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _forgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Text(_createMode ? 'Create account' : 'Sign in'),
                  ),

                  // Divider.
                  const SizedBox(height: 20),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 20),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50)),
                    onPressed: _busy ? null : _google,
                    icon: const FaIcon(FontAwesomeIcons.google, size: 18),
                    label: const Text('Continue with Google'),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _createMode = !_createMode),
                      child: Text.rich(TextSpan(
                        text: _createMode
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style: TextStyle(color: cs.onSurfaceVariant),
                        children: [
                          TextSpan(
                            text: _createMode ? 'Sign in' : 'Create one',
                            style: TextStyle(
                                color: cs.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You can keep using PDF Craft as a guest.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (_createMode) ...[
                    const SizedBox(height: 12),
                    _legalDisclaimer(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            text: 'Account created — check your email to verify.', color: Colors.green);
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
        _done('Signed in.');
      }
    } on AuthException catch (e) {
      // Blocked because the e-mail isn't verified → give a real way to verify, not a dead-end toast.
      if (!_createMode && _isVerifyError(e)) {
        if (mounted) await _showVerifyPrompt(_email.text.trim());
      } else {
        _fail(e.message);
      }
    } catch (e) {
      _fail('Something went wrong. Please try again.');
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
        title: const Text('Verify your email first'),
        content: Text(
            'Your email isn’t verified yet. We can resend the verification link to '
            '${email.isEmpty ? 'your email' : email} — open it, tap “Verify email”, then sign in again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Resend link'),
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
    setState(() => _busy = true);
    try {
      await AuthService().signInWithGoogle();
      await CreditService().load();
      _done('Signed in with Google.');
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Google sign-in failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confirms a sign-in that would leave a guest's credits behind.
  Future<bool?> _confirmSwitch(int credits) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch to your account?'),
        content: Text(
            "You have $credits credit${credits == 1 ? '' : 's'} as a guest. Signing in switches "
            "to your existing account and these guest credits won't carry over.\n\n"
            'Tip: choose “Create an account” instead to keep them.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign in anyway')),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _fail('Enter your email above first.');
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
          title: const Text('Check your email'),
          content: Text(
              'If an account exists for $email, we’ve sent a password-reset link. '
              'Open it to choose a new password, then come back and sign in.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      );
    } catch (e) {
      _fail('Could not send reset email. Please try again.');
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
        Text('By creating an account you agree to our ', style: base),
        GestureDetector(
            onTap: () => _openUrl(Constants.termsUrl), child: Text('Terms', style: link)),
        Text(' & ', style: base),
        GestureDetector(
            onTap: () => _openUrl(Constants.privacyUrl),
            child: Text('Privacy Policy', style: link)),
        Text('.', style: base),
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
