import 'package:flutter/material.dart';

Future<void> showMapMarkerInfoDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Map<String, String> details,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              Text(
                subtitle,
                style: TextStyle(color: Theme.of(dialogContext).hintColor),
              ),
              const SizedBox(height: 16),
            ],
            for (final entry in details.entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: Theme.of(dialogContext).hintColor,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (entry.key != details.keys.last) const Divider(height: 20),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
