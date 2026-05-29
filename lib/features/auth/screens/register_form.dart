import 'package:flutter/material.dart';

import '../auth_controller.dart';
import '../widgets/auth_text_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _esewaId = TextEditingController();
  final _district = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _esewaId.dispose();
    _district.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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
            controller: _fullName,
            label: 'Full name',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _phone,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _esewaId,
            label: 'eSewa ID',
            icon: Icons.account_balance_wallet_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _district,
            label: 'District',
            icon: Icons.location_on_outlined,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _password,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _confirmPassword,
            label: 'Confirm password',
            icon: Icons.lock_reset_outlined,
            obscureText: true,
            validator: _confirmPasswordValidator,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _createAccount,
            child: Text(_submitting ? 'Creating...' : 'Create Account'),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _confirmPasswordValidator(String? value) {
    final requiredMessage = _required(value);
    if (requiredMessage != null) {
      return requiredMessage;
    }
    return value == _password.text ? null : 'Passwords must match';
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthScope.of(context).register(
        fullName: _fullName.text,
        phone: _phone.text,
        esewaId: _esewaId.text,
        district: _district.text,
        password: _password.text,
      );
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (_) => false);
      }
    } on AuthValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
