import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../domain/models/cancellation_reason.dart';
import '../theme/ridons_colors.dart';

Future<CancellationSelection?> showCancellationReasonSheet({
  required BuildContext context,
  required String actor,
  required Future<List<CancellationReason>> Function() loadReasons,
}) async {
  final reasons = await loadReasons();
  if (!context.mounted) return null;
  return showModalBottomSheet<CancellationSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CancellationReasonSheet(actor: actor, reasons: reasons),
  );
}

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet({required this.actor, required this.reasons});

  final String actor;
  final List<CancellationReason> reasons;

  @override
  State<_CancellationReasonSheet> createState() =>
      _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  CancellationReason? selected;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final requiresNote = selected?.requiresNote == true;
    final canSubmit =
        selected != null && (!requiresNote || note.text.trim().isNotEmpty);
    return SafeArea(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'what_went_wrong'.tr(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'cancellation_reason_help'.tr(),
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .46,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.reasons.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                  itemBuilder: (_, index) {
                    final reason = widget.reasons[index];
                    return RadioListTile<CancellationReason>(
                      value: reason,
                      groupValue: selected,
                      contentPadding: EdgeInsets.zero,
                      activeColor: RidonsColors.primary,
                      title: Text(
                        reason.labelFor(language),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onChanged: (value) => setState(() {
                        selected = value;
                        note.clear();
                      }),
                    );
                  },
                ),
              ),
              if (requiresNote) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'details'.tr(),
                    hintText: 'tell_us_more'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton(
                onPressed: canSubmit
                    ? () => Navigator.pop(
                        context,
                        CancellationSelection(
                          code: selected!.code,
                          label: selected!.labelFor(language),
                          note: note.text.trim(),
                        ),
                      )
                    : null,
                child: Text('done'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
