import '../models/app_role.dart';

enum VerificationStatus { pending, approved, rejected, suspended }

class SessionUser {
  const SessionUser({
    required this.id,
    required this.phone,
    required this.role,
    this.name = '',
    this.firstName = '',
    this.lastName = '',
    this.locale = 'en',
    this.avatarKey = 'passenger',
    this.avatarUrl,
    this.vehiclePlate,
    this.verificationStatus = VerificationStatus.approved,
    this.rejectReason,
  });

  final String id;
  final String phone;
  final AppRole role;
  final String name;
  final String firstName;
  final String lastName;
  final String locale;
  final String avatarKey;
  final String? avatarUrl;
  final String? vehiclePlate;
  final VerificationStatus verificationStatus;
  final String? rejectReason;

  bool get isVerified =>
      !role.isDriver || verificationStatus == VerificationStatus.approved;

  bool get hasUploadedPhoto =>
      avatarKey == 'upload' && (avatarUrl ?? '').isNotEmpty;

  /// True when the user picked a photo or a color avatar — not the default.
  bool get hasChosenAvatar {
    if (hasUploadedPhoto) return true;
    const chosen = {'navy', 'primary', 'gold', 'mint'};
    return chosen.contains(avatarKey);
  }

  bool get needsProfile => firstName.trim().isEmpty;

  String get displayName {
    final combined = '$firstName $lastName'.trim();
    if (combined.isNotEmpty) return combined;
    if (name.trim().isNotEmpty) return name.trim();
    return role.isDriver ? 'Driver' : 'Passenger';
  }

  /// Short public form of the identity `users.id` (e.g. `pax_` / `drv_` + nanoid).
  String get passengerIdLabel => _idLabel('PAX');

  String get driverIdLabel => _idLabel('RDR');

  String get publicIdLabel => role.isDriver ? driverIdLabel : passengerIdLabel;

  String get roleIdCaption => role.isDriver
      ? 'Driver ID · $driverIdLabel'
      : 'Passenger ID · $passengerIdLabel';

  String _idLabel(String prefix) {
    final tail = id.contains('_') ? id.split('_').last : id;
    final cleaned = tail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (cleaned.isEmpty) return '$prefix-0000';
    final few = cleaned.length <= 6
        ? cleaned
        : cleaned.substring(cleaned.length - 6);
    return '$prefix-${few.toUpperCase()}';
  }

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    final roleRaw = '${json['role'] ?? 'passenger'}';
    return SessionUser(
      id: '${json['id'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      name: '${json['name'] ?? ''}',
      firstName: '${json['firstName'] ?? ''}',
      lastName: '${json['lastName'] ?? ''}',
      locale: '${json['locale'] ?? 'en'}',
      avatarKey: '${json['avatarKey'] ?? 'passenger'}',
      avatarUrl: json['avatarUrl']?.toString(),
      vehiclePlate: json['vehiclePlate']?.toString(),
      verificationStatus: VerificationStatus.values.firstWhere(
        (value) =>
            value.name ==
            '${json['verificationStatus'] ?? (roleRaw == 'driver' ? 'pending' : 'approved')}',
        orElse: () => roleRaw == 'driver'
            ? VerificationStatus.pending
            : VerificationStatus.approved,
      ),
      rejectReason: json['rejectReason']?.toString(),
      role: roleRaw == 'driver' ? AppRole.driver : AppRole.passenger,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final SessionUser user;

  bool get needsProfile => user.needsProfile;
}

class AuthException implements Exception {
  const AuthException(this.message, {this.code});
  final String message;
  final String? code;

  bool get isPhoneTaken => code == 'phone_taken';

  @override
  String toString() => message;
}
