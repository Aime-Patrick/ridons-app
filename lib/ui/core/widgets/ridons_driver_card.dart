import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../data/config/api_config.dart';
import '../theme/ridons_colors.dart';

class RidonsDriverCard extends StatelessWidget {
  const RidonsDriverCard({
    super.key,
    required this.name,
    required this.rating,
    this.plate,
    this.avatarUrl,
  });

  final String name;
  final double rating;
  final String? plate;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedAvatarUrl = avatarUrl == null
        ? null
        : avatarUrl!.startsWith('http')
        ? avatarUrl
        : '${defaultGatewayUrl()}$avatarUrl';
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: RidonsColors.primaryLight,
          backgroundImage: resolvedAvatarUrl != null
              ? CachedNetworkImageProvider(resolvedAvatarUrl)
              : null,
          child: resolvedAvatarUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: RidonsColors.primaryDark,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (plate != null)
                Text(
                  plate!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.ridonsMuted,
                      ),
                ),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: RidonsColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
