import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/notification_item.dart';
import '../../core/providers/session_providers.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/ridons_back_header.dart';
import 'view_models/notification_center_view_model.dart';

class NotificationInboxView extends ConsumerWidget {
  const NotificationInboxView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = ref.watch(notificationCenterProvider);
    return Scaffold(
      backgroundColor: context.ridonsPage,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: RidonsBackHeader(title: 'Notifications'),
                  ),
                  if (center.unreadCount > 0)
                    TextButton(
                      onPressed: center.busy ? null : center.markAllRead,
                      child: const Text('Mark all read'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: RidonsColors.primary,
                onRefresh: center.refresh,
                child: _NotificationList(center: center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.center});

  final NotificationCenterViewModel center;

  @override
  Widget build(BuildContext context) {
    if (center.loading && center.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (center.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 24),
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 48,
            color: context.ridonsMuted,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              center.errorMessage ?? 'You are all caught up.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.ridonsMuted),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: center.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = center.items[index];
        return _NotificationTile(
          item: item,
          onTap: () => center.markRead(item),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = _iconFor(item);
    return Material(
      color: item.read ? context.ridonsSheet : context.ridonsSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.read ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: item.read
                      ? context.ridonsFill
                      : RidonsColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(icon, color: RidonsColors.primary, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: context.ridonsInk,
                              fontWeight: item.read
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.read)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: RidonsColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: SizedBox(width: 8, height: 8),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(color: context.ridonsMuted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.ageLabel,
                      style: TextStyle(
                        color: context.ridonsMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationItem item) {
    final type = '${item.data['type'] ?? ''}'.toLowerCase();
    final text = '${item.title} ${item.body}'.toLowerCase();
    if (type.contains('safety') || text.contains('sos')) {
      return Icons.warning_amber_rounded;
    }
    if (type.contains('ride') || text.contains('ride')) {
      return Icons.directions_car_filled_outlined;
    }
    if (type.contains('offer') || text.contains('offer')) {
      return Icons.local_offer_outlined;
    }
    return Icons.notifications_none_rounded;
  }
}
