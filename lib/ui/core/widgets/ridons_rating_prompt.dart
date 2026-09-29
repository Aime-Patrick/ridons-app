import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';
import 'ridons_button.dart';
import 'ridons_star_rating.dart';
import 'ridons_text_field.dart';

class RidonsRatingPrompt extends StatelessWidget {
  const RidonsRatingPrompt({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.onCommentChanged,
    required this.onSubmit,
    this.submitLabel = 'submit_rating',
    this.isLoading = false,
    this.errorMessage,
  });

  final String title;
  final int value;
  final ValueChanged<int> onChanged;
  final ValueChanged<String> onCommentChanged;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: context.ridonsSheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.ridonsLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.ridonsInk,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          RidonsStarRating(value: value, onChanged: onChanged, size: 32),
          const SizedBox(height: 4),
          RidonsTextField(
            hint: 'add_comment_optional',
            onChanged: onCommentChanged,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: RidonsColors.primary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          RidonsButton(
            label: submitLabel,
            isLoading: isLoading,
            onPressed: value > 0 ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
