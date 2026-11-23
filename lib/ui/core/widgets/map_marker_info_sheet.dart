import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

/// Shows marker details without hiding the map behind a dialog.
///
/// The draggable sheet follows the same interaction pattern as the map
/// details UI in Google Maps: the map remains visible, while the user can
/// drag the sheet higher when more information is available.
Future<void> showMapMarkerInfoSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Map<String, String> details,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.34,
      minChildSize: 0.24,
      maxChildSize: 0.76,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Material(
          color: context.ridonsSheet,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.ridonsLine,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.ridonsSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _markerIcon(title),
                      color: RidonsColors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: context.ridonsInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.ridonsMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: context.ridonsFill,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'close'.tr(),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: context.ridonsMuted,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 22),
                Container(
                  decoration: BoxDecoration(
                    color: context.ridonsFill,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.ridonsLine),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < details.length; index++) ...[
                        _MarkerDetailRow(
                          label: details.keys.elementAt(index).tr(),
                          value: details.values.elementAt(index),
                          isStatus: details.keys.elementAt(index) == 'status',
                        ),
                        if (index < details.length - 1)
                          Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: context.ridonsLine,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

IconData _markerIcon(String title) => switch (title) {
  'your_location' => Icons.my_location_rounded,
  'driver' => Icons.two_wheeler_rounded,
  'passenger' => Icons.person_pin_circle_rounded,
  'dropoff_location' => Icons.location_on_rounded,
  _ => Icons.place_rounded,
};

class _MarkerDetailRow extends StatelessWidget {
  const _MarkerDetailRow({
    required this.label,
    required this.value,
    required this.isStatus,
  });

  final String label;
  final String value;
  final bool isStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.ridonsMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.ridonsInk,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isStatus) ...[
            const SizedBox(width: 10),
            Icon(
              Icons.check_circle_rounded,
              color: RidonsColors.success,
              size: 18,
            ),
          ],
        ],
      ),
    );
  }
}
