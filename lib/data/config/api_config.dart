import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Loaded from `env.json` (emulator). Override with
/// `--dart-define-from-file=env.usb.json` for a USB phone.
abstract final class RidonsEnv {
  static String apiUrl = '';
  static String identityUrl = '';
  static String locationUrl = '';
  static String tripUrl = '';
  static String placesUrl = '';
  static String pricingUrl = '';
  static String notificationUrl = '';
  static String paymentUrl = '';
  static String etaUrl = '';
  static String termsUrl = 'https://www.ridons.com/terms-and-conditions';
  static String privacyUrl = 'https://www.ridons.com/privacy-policy';
  static String policyVersion = '2026-10-17';

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('env.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      apiUrl = _str(map, 'RIDONS_API_URL');
      identityUrl = _str(map, 'RIDONS_IDENTITY_URL');
      locationUrl = _str(map, 'RIDONS_LOCATION_URL');
      tripUrl = _str(map, 'RIDONS_TRIP_URL');
      placesUrl = _str(map, 'RIDONS_PLACES_URL');
      pricingUrl = _str(map, 'RIDONS_PRICING_URL');
      notificationUrl = _str(map, 'RIDONS_NOTIFICATION_URL');
      paymentUrl = _str(map, 'RIDONS_PAYMENT_URL');
      etaUrl = _str(map, 'RIDONS_ETA_URL');
      final configuredTerms = _str(map, 'RIDONS_TERMS_URL');
      final configuredPrivacy = _str(map, 'RIDONS_PRIVACY_URL');
      final configuredPolicyVersion = _str(map, 'RIDONS_POLICY_VERSION');
      if (configuredTerms.isNotEmpty) termsUrl = configuredTerms;
      if (configuredPrivacy.isNotEmpty) privacyUrl = configuredPrivacy;
      if (configuredPolicyVersion.isNotEmpty) {
        policyVersion = configuredPolicyVersion;
      }
    } catch (_) {}

    const defineApi = String.fromEnvironment('RIDONS_API_URL');
    const defineIdentity = String.fromEnvironment('RIDONS_IDENTITY_URL');
    const defineLocation = String.fromEnvironment('RIDONS_LOCATION_URL');
    const defineTrip = String.fromEnvironment('RIDONS_TRIP_URL');
    const definePlaces = String.fromEnvironment('RIDONS_PLACES_URL');
    const definePricing = String.fromEnvironment('RIDONS_PRICING_URL');
    const defineNotification = String.fromEnvironment(
      'RIDONS_NOTIFICATION_URL',
    );
    const definePayment = String.fromEnvironment('RIDONS_PAYMENT_URL');
    const defineEta = String.fromEnvironment('RIDONS_ETA_URL');
    const defineTerms = String.fromEnvironment('RIDONS_TERMS_URL');
    const definePrivacy = String.fromEnvironment('RIDONS_PRIVACY_URL');
    const definePolicyVersion = String.fromEnvironment('RIDONS_POLICY_VERSION');
    if (defineApi.isNotEmpty) apiUrl = defineApi;
    if (defineIdentity.isNotEmpty) identityUrl = defineIdentity;
    if (defineLocation.isNotEmpty) locationUrl = defineLocation;
    if (defineTrip.isNotEmpty) tripUrl = defineTrip;
    if (definePlaces.isNotEmpty) placesUrl = definePlaces;
    if (definePricing.isNotEmpty) pricingUrl = definePricing;
    if (defineNotification.isNotEmpty) notificationUrl = defineNotification;
    if (definePayment.isNotEmpty) paymentUrl = definePayment;
    if (defineEta.isNotEmpty) etaUrl = defineEta;
    if (defineTerms.isNotEmpty) termsUrl = defineTerms;
    if (definePrivacy.isNotEmpty) privacyUrl = definePrivacy;
    if (definePolicyVersion.isNotEmpty) policyVersion = definePolicyVersion;
  }

  static String _str(Map<String, dynamic> map, String key) {
    final value = map[key];
    return value is String ? value : '';
  }
}

/// Gateway the app talks to. Dart-define → env.json → platform default.
String defaultGatewayUrl() {
  const fromDefine = String.fromEnvironment('RIDONS_API_URL', defaultValue: '');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (RidonsEnv.apiUrl.isNotEmpty) return RidonsEnv.apiUrl;
  if (kIsWeb) return 'http://127.0.0.1:8100';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8100';
    default:
      return 'http://127.0.0.1:8100';
  }
}

String e164Phone(String localDigits, {String countryCode = '+250'}) {
  var digits = localDigits.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.startsWith(countryCode.replaceAll('+', ''))) {
    return '+$digits';
  }
  return '$countryCode$digits';
}

bool isValidRwandaLocal(String localDigits) {
  final digits = localDigits.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 8 && digits.length <= 10;
}
