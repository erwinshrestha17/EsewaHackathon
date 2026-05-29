import 'package:flutter/material.dart';

import 'settings_models.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({required this.state, super.key});

  final SettingsState state;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _displayName;
  late final TextEditingController _phone;
  late final TextEditingController _esewaId;
  late final TextEditingController _district;
  late final TextEditingController _avatarInitials;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.state.displayName);
    _phone = TextEditingController(text: widget.state.phone);
    _esewaId = TextEditingController(text: widget.state.esewaId);
    _district = TextEditingController(text: widget.state.district);
    _avatarInitials = TextEditingController(text: widget.state.avatarInitials);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    _esewaId.dispose();
    _district.dispose();
    _avatarInitials.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Profile',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Text(
                      _avatarInitials.text.trim().isEmpty
                          ? 'ES'
                          : _avatarInitials.text.trim().toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _avatarInitials,
                      maxLength: 3,
                      decoration: const InputDecoration(
                        labelText: 'Avatar placeholder',
                        helperText: 'Use initials for MVP',
                        counterText: '',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayName,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _esewaId,
                decoration: const InputDecoration(
                  labelText: 'eSewa ID',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _district,
                decoration: const InputDecoration(
                  labelText: 'District',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final displayName = _displayName.text.trim();
    Navigator.pop(
      context,
      ProfileDraft(
        displayName: displayName.isEmpty
            ? widget.state.displayName
            : displayName,
        phone: _phone.text.trim().isEmpty
            ? widget.state.phone
            : _phone.text.trim(),
        esewaId: _esewaId.text.trim().isEmpty
            ? widget.state.esewaId
            : _esewaId.text.trim(),
        district: _district.text.trim().isEmpty
            ? widget.state.district
            : _district.text.trim(),
        avatarInitials: _normalizedInitials(displayName),
      ),
    );
  }

  String _normalizedInitials(String displayName) {
    final typed = _avatarInitials.text.trim().toUpperCase();
    if (typed.isNotEmpty) {
      return typed;
    }
    final parts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return widget.state.avatarInitials;
    }
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }
}
