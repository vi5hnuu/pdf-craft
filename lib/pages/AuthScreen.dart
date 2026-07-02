import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(_createMode ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.workspace_premium_outlined,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  _createMode
                      ? 'Save your credits & sync across devices'
                      : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                if (_createMode)
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                if (_createMode) const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_createMode ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _createMode = !_createMode),
                  child: Text(_createMode
                      ? 'Already have an account? Sign in'
                      : "New here? Create an account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_createMode) {
        final msg = await AuthService().convertGuest(
          email: _email.text.trim(),
          password: _password.text,
          firstName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
        _done(msg);
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

  void _done(String message) {
    if (!mounted) return;
    NotificationService.showSnackbar(text: message, color: Colors.green);
    Navigator.of(context).pop();
  }

  void _fail(String message) {
    NotificationService.showSnackbar(text: message, color: Colors.red);
  }
}
