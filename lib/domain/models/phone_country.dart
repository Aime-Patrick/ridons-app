class PhoneCountry {
  const PhoneCountry({
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.flag,
    this.minLength = 4,
    this.maxLength = 14,
    this.isDefault = false,
  });

  final String iso2;
  final String name;
  final String dialCode;
  final String flag;
  final int minLength;
  final int maxLength;
  final bool isDefault;

  static const rwanda = PhoneCountry(
    iso2: 'RW',
    name: 'Rwanda',
    dialCode: '+250',
    flag: '🇷🇼',
    minLength: 9,
    maxLength: 9,
    isDefault: true,
  );

  factory PhoneCountry.fromJson(Map<String, dynamic> json) {
    return PhoneCountry(
      iso2: (json['iso2'] ?? 'RW').toString().toUpperCase(),
      name: (json['name'] ?? '').toString(),
      dialCode: (json['dialCode'] ?? '+250').toString(),
      flag: (json['flag'] ?? '').toString(),
      minLength: (json['minLength'] as num?)?.toInt() ?? 4,
      maxLength: (json['maxLength'] as num?)?.toInt() ?? 14,
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'iso2': iso2,
    'name': name,
    'dialCode': dialCode,
    'flag': flag,
    'minLength': minLength,
    'maxLength': maxLength,
    'isDefault': isDefault,
  };
}

class PhoneCountriesConfig {
  const PhoneCountriesConfig({
    required this.defaultCountry,
    required this.countries,
  });

  final String defaultCountry;
  final List<PhoneCountry> countries;

  static const fallback = PhoneCountriesConfig(
    defaultCountry: 'RW',
    countries: [PhoneCountry.rwanda],
  );

  PhoneCountry get resolvedDefault {
    if (countries.isEmpty) return PhoneCountry.rwanda;
    return countries.firstWhere(
      (c) => c.iso2 == defaultCountry || c.isDefault,
      orElse: () => countries.first,
    );
  }

  factory PhoneCountriesConfig.fromJson(Map<String, dynamic> json) {
    final rawList = json['countries'];
    final parsed = <PhoneCountry>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final country = PhoneCountry.fromJson(item);
          if (country.dialCode.isNotEmpty && country.iso2.isNotEmpty) {
            parsed.add(country);
          }
        }
      }
    }
    if (parsed.isEmpty) {
      return fallback;
    }
    final def = (json['defaultCountry'] ?? parsed.first.iso2)
        .toString()
        .toUpperCase();
    return PhoneCountriesConfig(defaultCountry: def, countries: parsed);
  }

  Map<String, dynamic> toJson() => {
    'defaultCountry': defaultCountry,
    'countries': countries.map((c) => c.toJson()).toList(),
  };
}
