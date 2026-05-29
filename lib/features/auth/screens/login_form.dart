import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/auth_text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthTextField(
            controller: _identifier,
            label: 'Phone number or eSewa ID',
            icon: Icons.phone_iphone_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _password,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            validator: _required,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _login,
            child: Text(_submitting ? 'Logging in...' : 'Login'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _continueAsDemo,
            icon: const Icon(Icons.person_outline),
            label: const Text('Continue as Demo User'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthScope.of(
        context,
      ).login(identifier: _identifier.text, password: _password.text);
      _openMain();
    } on AuthValidationException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _continueAsDemo() async {
    setState(() => _submitting = true);
    await AuthScope.of(context).continueAsDemoUser();
    _openMain();
    if (mounted) {
      setState(() => _submitting = false);
    }
  }

  void _openMain() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
