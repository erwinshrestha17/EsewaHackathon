import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_controller.dart';
import '../widgets/auth_text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _mPin = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _mPin.dispose();
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
            controller: _mPin,
            label: 'M-PIN',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: _mPinValidator,
          ),
          const SizedBox(height: 10),
          Text(
            'Use your 4-digit M-PIN or device biometric unlock.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _loginWithMpin,
            child: Text(_submitting ? 'Verifying...' : 'Login with M-PIN'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting ? null : _loginWithBiometric,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Login with biometric'),
          ),
        ],
      ),
    );
  }

  String? _mPinValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your M-PIN';
    }
    return RegExp(r'^\d{4}$').hasMatch(value.trim())
        ? null
        : 'Enter a 4-digit M-PIN';
  }

  Future<void> _loginWithMpin() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    await _submit(() => AuthScope.of(context).loginWithMpin(_mPin.text));
  }

  Future<void> _loginWithBiometric() async {
    await _submit(() => AuthScope.of(context).loginWithBiometric());
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() => _submitting = true);
    try {
      await action();
      _openMain();
    } on AuthValidationException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
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
