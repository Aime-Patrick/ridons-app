import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/config/api_config.dart';
import '../../../domain/models/session_user.dart';
import '../../core/theme/ridons_colors.dart';

class AvatarPreset {
  const AvatarPreset({
    required this.key,
    required this.label,
    this.asset,
    this.color,
  });

  final String key;
  final String label;
  final String? asset;
  final Color? color;

  static const all = [
    AvatarPreset(
      key: 'passenger',
      label: 'Classic',
      color: RidonsColors.primary,
      asset: 'assets/brand/logo_icon.svg',
    ),
    AvatarPreset(key: 'navy', label: 'Navy', color: RidonsColors.navy),
    AvatarPreset(key: 'primary', label: 'Ridons', color: RidonsColors.primary),
    AvatarPreset(key: 'gold', label: 'Gold', color: RidonsColors.accent),
    AvatarPreset(key: 'mint', label: 'Mint', color: RidonsColors.success),
  ];
}

class PassengerAvatar extends StatelessWidget {
  const PassengerAvatar({
    super.key,
    required this.user,
    this.radius = 32,
    this.token,
  });

  final SessionUser? user;
  final double radius;
  final String? token;

  @override
  Widget build(BuildContext context) {
    if (user?.hasUploadedPhoto == true &&
        token != null &&
        token!.isNotEmpty) {
      final path = user!.avatarUrl!;
      final url = path.startsWith('http') ? path : '${defaultGatewayUrl()}$path';
      return CachedNetworkImage(
        imageUrl: url,
        httpHeaders: {'Authorization': 'Bearer $token'},
        imageBuilder: (context, provider) => CircleAvatar(
          radius: radius,
          backgroundImage: provider,
        ),
        placeholder: (_, _) =>
            _colored(radius, RidonsColors.inputFill, dark: true),
        errorWidget: (_, _, _) => _personIcon(radius),
      );
    }
    return _presetAvatar(user?.avatarKey ?? 'passenger');
  }

  Widget _presetAvatar(String key) {
    if (key.isEmpty || key == 'passenger') {
      return _personIcon(radius);
    }
    AvatarPreset? preset;
    for (final item in AvatarPreset.all) {
      if (item.key == key) {
        preset = item;
        break;
      }
    }
    if (preset == null || preset.asset != null) {
      return _personIcon(radius);
    }
    return _colored(radius, preset.color ?? RidonsColors.navy);
  }

  static Widget _personIcon(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF4285F4),
      child: Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: radius,
      ),
    );
  }

  static Widget _colored(double radius, Color color, {bool dark = false}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(
        Icons.person,
        color: dark ? RidonsColors.navy : Colors.white,
        size: radius,
      ),
    );
  }
}
