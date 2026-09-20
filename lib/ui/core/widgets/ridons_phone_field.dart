import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ridons_colors.dart';

/// Country code + phone number field (+250 default for Rwanda).
class RidonsPhoneField extends StatelessWidget {
  const RidonsPhoneField({
    super.key,
    required this.controller,
    this.countryCode = '+250',
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String countryCode;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ink = context.ridonsInk;
    final muted = context.ridonsMuted;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: context.ridonsFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RidonsColors.primary),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Text(
            '🇷🇼  $countryCode',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
          ),
          Icon(Icons.keyboard_arrow_down, size: 20, color: muted),
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: context.ridonsLine,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              enabled: enabled,
              readOnly: !enabled,
              keyboardType: TextInputType.phone,
              keyboardAppearance: dark ? Brightness.dark : Brightness.light,
              cursorColor: RidonsColors.primary,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: '788 888 888',
                hintStyle: TextStyle(color: muted, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
