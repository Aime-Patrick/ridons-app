import 'package:flutter/material.dart';

Future<void> showMapMarkerInfoSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Map<String, String> details,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 16),
            for (final entry in details.entries) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(color: Colors.grey.shade600),
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
    ),
  );
}
