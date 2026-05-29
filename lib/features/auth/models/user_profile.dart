import 'dart:convert';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.phone,
    required this.esewaId,
    required this.district,
    required this.createdAt,
    this.dateOfBirth,
    this.avatarUrl,
  });

  factory UserProfile.demo() {
    return UserProfile(
      id: activeUserId,
      displayName: 'Erwin Shrestha',
      phone: '98XXXXXXXX',
      esewaId: 'erwin@esewa',
      district: 'Bharatpur',
      createdAt: DateTime(2026, 5, 1, 10),
      dateOfBirth: DateTime(1998, 1, 1),
    );
  }

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      id: json['id'] as String? ?? activeUserId,
      displayName: json['displayName'] as String? ?? 'Erwin Shrestha',
      phone: json['phone'] as String? ?? '98XXXXXXXX',
      esewaId: json['esewaId'] as String? ?? 'erwin@esewa',
      district: json['district'] as String? ?? 'Bharatpur',
      avatarUrl: json['avatarUrl'] as String?,
      dateOfBirth: DateTime.tryParse(json['dateOfBirth'] as String? ?? ''),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime(2026, 5, 1, 10),
    );
  }

  factory UserProfile.fromJsonString(String source) {
    return UserProfile.fromJson(jsonDecode(source) as Map<String, Object?>);
  }

  static const activeUserId = 'u-sita';

  final String id;
  final String displayName;
  final String phone;
  final String esewaId;
  final String district;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime? dateOfBirth;

  String get firstName {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Friend' : parts.first;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return 'S';
    }
    return parts.take(2).map((part) => part[0]).join().toUpperCase();
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'phone': phone,
      'esewaId': esewaId,
      'district': district,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
      'dateOfBirth': dateOfBirth?.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  UserProfile copyWith({
    String? id,
    String? displayName,
    String? phone,
    String? esewaId,
    String? district,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? dateOfBirth,
  }) {
    return UserProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      esewaId: esewaId ?? this.esewaId,
      district: district ?? this.district,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}
