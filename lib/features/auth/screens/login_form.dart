import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_controller.dart';
import '../nepal_mobile.dart';
import '../widgets/auth_text_field.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _mPin = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _phone.dispose();
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
            controller: _phone,
            label: 'Nepal mobile number',
            icon: Icons.phone_iphone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixText: '+977 ',
            inputFormatters: const [NepalMobileInputFormatter()],
            validator: _nepalMobileValidator,
          ),
          const SizedBox(height: 12),
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
            'Use the mobile number and M-PIN you created during signup.',
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
        ],
      ),
    );
  }

  String? _nepalMobileValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your phone number';
    }
    final mobile = normalizeNepalMobile(value);
    if (mobile == null &&
        value.replaceAll(RegExp(r'[^0-9]'), '').length != 10) {
      return 'Enter exactly 10 digits after +977.';
    }
    return mobile != null ? null : 'Enter a valid Nepal mobile number.';
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
    await _submit(
      () => AuthScope.of(
        context,
      ).loginWithMpin(phone: _phone.text, mPin: _mPin.text),
    );
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
