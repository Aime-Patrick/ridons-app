import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/ridons_colors.dart';

class RidonsNotificationBell extends StatelessWidget {
  const RidonsNotificationBell({
    super.key,
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = unreadCount > 99 ? '99+' : '$unreadCount';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'notifications'.tr(),
          onPressed: onPressed,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 4,
            top: 2,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: RidonsColors.primary,
                  shape: BoxShape.circle,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
