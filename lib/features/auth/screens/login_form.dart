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
  final _otp = TextEditingController(text: '123456');
  var _submitting = false;
  var _otpRequested = false;
  var _biometricEnabled = true;

  @override
  void dispose() {
    _identifier.dispose();
    _otp.dispose();
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
            label: 'Nepal mobile number',
            icon: Icons.phone_iphone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _nepalMobileValidator,
          ),
          if (_otpRequested) ...[
            const SizedBox(height: 12),
            AuthTextField(
              controller: _otp,
              label: '6-digit OTP',
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              validator: _otpValidator,
            ),
            const SizedBox(height: 8),
            const Text(
              'Resend available in 00:29',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _biometricEnabled,
              title: const Text('Enable biometric login'),
              subtitle: const Text('Use device unlock after this demo login.'),
              onChanged: (value) => setState(() => _biometricEnabled = value),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _login,
            child: Text(
              _submitting
                  ? 'Verifying...'
                  : _otpRequested
                  ? 'Verify & Continue'
                  : 'Continue',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _submitting
                ? null
                : () => _showError(
                    'Use a Nepal mobile number such as 98XXXXXXXX or +977 98XXXXXXXX.',
                  ),
            icon: const Icon(Icons.help_outline),
            label: const Text('Need help?'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _nepalMobileValidator(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    final normalized = _normalizeNepalMobile(value!);
    final valid = RegExp(r'^9[678]\d{8}$').hasMatch(normalized);
    return valid ? null : 'Enter a valid Nepal mobile number.';
  }

  String _normalizeNepalMobile(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 13 && digits.startsWith('977')) {
      return digits.substring(3);
    }
    return digits;
  }

  String? _otpValidator(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    return value!.trim().length == 6 ? null : 'Enter the 6-digit OTP';
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_otpRequested) {
      setState(() => _otpRequested = true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthScope.of(
        context,
      ).login(identifier: _identifier.text, password: 'demo-password');
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
