import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../domain/models/phone_country.dart';
import '../theme/ridons_colors.dart';

/// Country code + phone number field with selectable allowed countries.
class RidonsPhoneField extends StatelessWidget {
  const RidonsPhoneField({
    super.key,
    required this.controller,
    this.countryCode = '+250',
    this.countries = const [PhoneCountry.rwanda],
    this.selectedCountry,
    this.onCountryChanged,
    this.onChanged,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String countryCode;
  final List<PhoneCountry> countries;
  final PhoneCountry? selectedCountry;
  final ValueChanged<PhoneCountry>? onCountryChanged;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;

  PhoneCountry get _activeCountry {
    if (selectedCountry != null) return selectedCountry!;
    if (countries.isNotEmpty) {
      return countries.firstWhere(
        (c) => c.dialCode == countryCode,
        orElse: () => countries.first,
      );
    }
    return PhoneCountry.rwanda;
  }

  Future<void> _pickCountry(BuildContext context) async {
    if (!enabled || onCountryChanged == null || countries.isEmpty) return;
    final chosen = await showModalBottomSheet<PhoneCountry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CountryPickerSheet(
        countries: countries,
        selectedIso2: _activeCountry.iso2,
      ),
    );
    if (chosen != null) {
      onCountryChanged!(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = context.ridonsInk;
    final muted = context.ridonsMuted;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = _activeCountry;
    final canPick = enabled && onCountryChanged != null && countries.length > 1;

    return Container(
      decoration: BoxDecoration(
        color: context.ridonsFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RidonsColors.primary),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          InkWell(
            onTap: canPick ? () => _pickCountry(context) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${active.flag.isNotEmpty ? '${active.flag}  ' : ''}${active.dialCode}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600, color: ink),
                  ),
                  if (canPick) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down, size: 20, color: muted),
                  ],
                ],
              ),
            ),
          ),
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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: ink, fontWeight: FontWeight.w600),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: active.iso2 == 'RW'
                    ? 'phone_hint'.tr()
                    : '7XX XXX XXX',
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

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selectedIso2,
  });

  final List<PhoneCountry> countries;
  final String selectedIso2;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.countries.where((c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.iso2.toLowerCase().contains(q) ||
          c.dialCode.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: SizedBox(
        height: _countrySheetHeight(context),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.ridonsLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'select_country'.tr(),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (widget.countries.length > 5)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'search'.tr(),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final country = filtered[index];
                  final selected = country.iso2 == widget.selectedIso2;
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 22),
                    ),
                    title: Text(
                      country.name,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: Text(
                      country.dialCode,
                      style: TextStyle(
                        color: selected
                            ? RidonsColors.primary
                            : context.ridonsMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _countrySheetHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        (media.size.height - media.padding.top - media.viewInsets.bottom)
            .clamp(0.0, media.size.height)
            .toDouble();
    return availableHeight * 0.72;
  }
}
