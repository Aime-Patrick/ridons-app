import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/ridons_colors.dart';

class RidonsTextField extends StatelessWidget {
  const RidonsTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.obscureText = false,
    this.prefix,
    this.suffix,
    this.enabled = true,
    this.autofocus = false,
    this.large = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final Widget? prefix;
  final Widget? suffix;
  final bool enabled;
  final bool autofocus;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (large) {
      return Container(
        height: 90,
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
        decoration: BoxDecoration(
          color: context.ridonsDark
              ? RidonsColors.darkSurface
              : RidonsColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.ridonsLine, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label != null)
              Text(
                label!.tr(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.ridonsInk,
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                ),
              ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                onChanged: onChanged,
                obscureText: obscureText,
                enabled: enabled,
                autofocus: autofocus,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration.collapsed(
                  hintText: hint?.tr(),
                ),
                keyboardAppearance: Theme.of(context).brightness,
                cursorColor: Theme.of(context).colorScheme.primary,
                style: TextStyle(color: context.ridonsInk, fontSize: 17),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!.tr(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.ridonsInk,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onChanged: onChanged,
          obscureText: obscureText,
          enabled: enabled,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint?.tr(),
            prefixIcon: prefix,
            suffixIcon: suffix,
          ),
          keyboardAppearance: Theme.of(context).brightness,
          cursorColor: Theme.of(context).colorScheme.primary,
          style: TextStyle(color: context.ridonsInk),
        ),
      ],
    );
  }
}
