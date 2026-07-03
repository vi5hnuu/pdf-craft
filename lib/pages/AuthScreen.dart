import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:pdf_craft/services/auth/AuthApi.dart';
import 'package:pdf_craft/singletons/AuthService.dart';
import 'package:pdf_craft/singletons/CreditService.dart';
import 'package:pdf_craft/singletons/NotificationService.dart';

/// Sign-in / create-account screen. The app is guest-first, so "Create account"
/// converts the current guest (keeping their credits); "Sign in" switches to an
/// existing account. Google sign-in is offered for one-tap access.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _createMode = true; // guests most often want to create/keep their account
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
        if (mounted) await _showVerifyEmailDialog(_email.text.trim());
        if (mounted) Navigator.of(context).pop();
      } else {
        await AuthService().login(_email.text.trim(), _password.text);
        await CreditService().load(); // switched account → reload its balance
        _done('Signed in.');
      }
    } on AuthException catch (e) {
      _fail(e.message);
    } catch (e) {
      _fail('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

  Future<void> _forgotPassword() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      _fail('Enter your email first.');
      return;
    }
    try {
      final msg = await AuthService().forgotPassword(_email.text.trim());
      NotificationService.showSnackbar(text: msg, color: Colors.green);
    } catch (e) {
      _fail('Could not send reset email.');
    }
  }

  /// Nudges the user to verify their e-mail, with a resend option. The account already
  /// works (their guest session is preserved) — verification just confirms the address.
  Future<void> _showVerifyEmailDialog(String email) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined, size: 40),
        title: const Text('Verify your email'),
        content: Text(
            "We've sent a verification link to $email. Open it to confirm your address. "
            'You can keep using the app in the meantime.'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await AuthService().reVerify(email);
                NotificationService.showSnackbar(
                    text: 'Verification email resent.', color: Colors.green);
              } catch (_) {
                NotificationService.showSnackbar(
                    text: 'Could not resend right now.', color: Colors.red);
              }
            },
            child: const Text('Resend'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
