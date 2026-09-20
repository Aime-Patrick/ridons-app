import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
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
            hintText: hint,
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
