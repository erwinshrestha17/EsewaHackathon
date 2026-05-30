import 'package:flutter/material.dart';

import '../auth/models/user_profile.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({required this.profile, super.key});

  final UserProfile profile;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _displayName;
  late final TextEditingController _phone;
  late final TextEditingController _esewaId;
  late final TextEditingController _district;

  @override
  void initState() {
    super.initState();
    _displayName = TextEditingController(text: widget.profile.displayName);
    _phone = TextEditingController(text: widget.profile.phone);
    _esewaId = TextEditingController(text: widget.profile.esewaId);
    _district = TextEditingController(text: widget.profile.district);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _phone.dispose();
    _esewaId.dispose();
    _district.dispose();
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
                    child: Text(_draftInitials),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your avatar initials update from your display name.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
                onChanged: (_) => setState(() {}),
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
      widget.profile.copyWith(
        displayName: displayName.isEmpty
            ? widget.profile.displayName
            : displayName,
        phone: _phone.text.trim().isEmpty
            ? widget.profile.phone
            : _phone.text.trim(),
        esewaId: _esewaId.text.trim().isEmpty
            ? widget.profile.esewaId
            : _esewaId.text.trim(),
        district: _district.text.trim().isEmpty
            ? widget.profile.district
            : _district.text.trim(),
      ),
    );
  }

  String get _draftInitials {
    final parts = _displayName.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return widget.profile.initials;
    }
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }
}
