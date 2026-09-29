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
      initialChildSize: 0.36,
      minChildSize: 0.24,
      maxChildSize: 0.82,
      expand: false,
      builder: (context, scrollController) {
        final theme = Theme.of(context);
        return Material(
          color: context.ridonsSheet,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.ridonsLine,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: context.ridonsMuted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final entry in details.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: context.ridonsMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Text(
                          entry.value,
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key != details.keys.last)
                  Divider(height: 1, color: context.ridonsLine),
              ],
            ],
          ),
        );
      },
    ),
  );
}
