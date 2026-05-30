import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth_controller.dart';
import '../nepal_mobile.dart';
import '../widgets/auth_text_field.dart';

class RegisterForm extends StatefulWidget {
  const RegisterForm({super.key});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _mobileNumber = TextEditingController();
  final _dateOfBirth = TextEditingController();
  final _mPin = TextEditingController();
  final _otp = TextEditingController();
  var _submitting = false;
  var _otpRequested = false;
  String? _otpStatus;

  @override
  void dispose() {
    _fullName.dispose();
    _mobileNumber.dispose();
    _dateOfBirth.dispose();
    _mPin.dispose();
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
            controller: _fullName,
            label: 'Full name',
            icon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: _fullNameValidator,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _mobileNumber,
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
            controller: _dateOfBirth,
            label: 'Date of birth',
            hintText: 'YYYY-MM-DD',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            validator: _dateOfBirthValidator,
          ),
          const SizedBox(height: 12),
          AuthTextField(
            controller: _mPin,
            label: 'Create M-PIN',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            obscureText: true,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: _mPinValidator,
          ),
          if (_otpRequested) ...[
            const SizedBox(height: 12),
            AuthTextField(
              controller: _otp,
              label: '6-digit OTP',
              icon: Icons.verified_user_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: _otpValidator,
            ),
            const SizedBox(height: 8),
            if (_otpStatus != null)
              Text(
                _otpStatus!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _continue,
            child: Text(
              _submitting
                  ? 'Creating...'
                  : _otpRequested
                  ? 'Verify OTP & Create Account'
                  : 'Send OTP',
            ),
          ),
        ],
      ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Required' : null;
  }

  String? _fullNameValidator(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    return value!.trim().length >= 2 ? null : 'Enter your full name';
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

  String? _dateOfBirthValidator(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    final parsed = DateTime.tryParse(value!.trim());
    if (parsed == null) {
      return 'Use YYYY-MM-DD';
    }
    final today = DateTime.now();
    if (parsed.isAfter(DateTime(today.year, today.month, today.day))) {
      return 'Date of birth cannot be in future';
    }
    return null;
  }

  String? _mPinValidator(String? value) {
    final required = _required(value);
    if (required != null) {
      return required;
    }
    return RegExp(r'^\d{4}$').hasMatch(value!.trim())
        ? null
        : 'Enter a 4-digit M-PIN';
  }

  String? _otpValidator(String? value) {
    if (!_otpRequested) {
      return null;
    }
    final required = _required(value);
    if (required != null) {
      return required;
    }
    return RegExp(r'^\d{6}$').hasMatch(value!.trim())
        ? null
        : 'Enter the 6-digit OTP';
  }

  Future<void> _continue() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_otpRequested) {
      setState(() => _submitting = true);
      try {
        final challenge = await AuthScope.of(
          context,
        ).requestSignupOtp(phone: _mobileNumber.text);
        if (!mounted) {
          return;
        }
        setState(() {
          _otpRequested = true;
          _otpStatus =
              '${challenge.message} It expires in ${challenge.expiresInSeconds ~/ 60} minutes.';
        });
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
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthScope.of(context).register(
        fullName: _fullName.text,
        mobileNumber: _mobileNumber.text,
        dateOfBirth: DateTime.parse(_dateOfBirth.text.trim()),
        mPin: _mPin.text,
        otp: _otp.text,
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
