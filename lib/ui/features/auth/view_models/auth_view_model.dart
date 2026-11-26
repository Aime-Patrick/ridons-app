import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../../data/config/api_config.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/services/google_sign_in_service.dart';
import '../../../../domain/models/app_role.dart';
import '../../../../domain/models/phone_country.dart';
import '../../../../domain/models/session_user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required GoogleSignInService googleSignIn,
  }) : _auth = authRepository,
       _googleSignIn = googleSignIn;

  final AuthRepository _auth;
  final GoogleSignInService _googleSignIn;

  PhoneCountry selectedCountry = PhoneCountry.rwanda;
  bool _userPickedCountry = false;
  String pendingPhone = '';
  String otpCode = '';
  bool sending = false;
  bool testOtpMode = false;
  bool verifying = false;
  bool savingProfile = false;
  bool googleSigningIn = false;
  bool phoneTaken = false;
  bool userNotFound = false;
  String? errorMessage;
  String? googlePhoneLinkToken;
  int resendInSec = 0;
  bool signupTermsAccepted = false;
  bool signupPrivacyAccepted = false;
  String signupPolicyVersion = RidonsEnv.policyVersion;

  void setSignupConsent({required bool accepted}) {
    signupTermsAccepted = accepted;
    signupPrivacyAccepted = accepted;
    notifyListeners();
  }

  void _clearSignupConsent() {
    signupTermsAccepted = false;
    signupPrivacyAccepted = false;
  }

  Timer? _resendTimer;

  String get displayPhone =>
      pendingPhone.isEmpty ? selectedCountry.dialCode : pendingPhone;

  Future<AuthSession?> signInWithGoogle({required AppRole role}) async {
    if (googleSigningIn) return null;
    errorMessage = null;
    googlePhoneLinkToken = null;
    googleSigningIn = true;
    notifyListeners();
    try {
      final idToken = await _googleSignIn.signInForIdToken();
      if (idToken == null) return null;
      final result = await _auth.googleLogin(
        idToken: idToken,
        role: role,
        termsAccepted: true,
        privacyAccepted: true,
        policyVersion: signupPolicyVersion,
      );
      if (result.requiresPhone) {
        googlePhoneLinkToken = result.pendingToken;
        pendingPhone = '';
        _clearSignupConsent();
        return null;
      }
      final session = result.session;
      if (session == null) {
        errorMessage = 'google_signin_failed';
        return null;
      }
      _clearSignupConsent();
      return session;
    } on AuthException catch (e) {
      errorMessage = e.message;
      return null;
    } on PlatformException catch (e) {
      errorMessage = e.code == 'sign_in_canceled'
          ? null
          : 'google_signin_failed';
      return null;
    } catch (_) {
      errorMessage = 'google_signin_failed';
      return null;
    } finally {
      googleSigningIn = false;
      notifyListeners();
    }
  }

  void setSelectedCountry(PhoneCountry country) {
    _userPickedCountry = true;
    selectedCountry = country;
    errorMessage = null;
    notifyListeners();
  }

  void updatePhoneInput(String localDigits) {
    if (errorMessage == null || errorMessage == 'country_not_allowed') return;
    final isValid = isValidPhoneForCountry(
      localDigits,
      iso2: selectedCountry.iso2,
      dialCode: selectedCountry.dialCode,
      minLength: selectedCountry.minLength,
      maxLength: selectedCountry.maxLength,
    );
    if (!isValid) return;
    errorMessage = null;
    phoneTaken = false;
    userNotFound = false;
    notifyListeners();
  }

  void syncAllowedCountries(PhoneCountriesConfig config) {
    final countries = config.countries;
    if (countries.isEmpty) return;
    final stillAllowed = countries.any((c) => c.iso2 == selectedCountry.iso2);
    if (!_userPickedCountry || !stillAllowed) {
      final next = config.resolvedDefault;
      if (next.iso2 != selectedCountry.iso2 ||
          next.dialCode != selectedCountry.dialCode) {
        selectedCountry = next;
        notifyListeners();
      }
    }
  }

  void updateOtp(String code) {
    otpCode = code;
    if (errorMessage != null || phoneTaken || userNotFound) {
      errorMessage = null;
      phoneTaken = false;
      userNotFound = false;
      notifyListeners();
    }
  }

  Future<bool> sendCode(String localDigits, {AppRole? role}) async {
    errorMessage = null;
    phoneTaken = false;
    userNotFound = false;
    if (!isValidPhoneForCountry(
      localDigits,
      iso2: selectedCountry.iso2,
      dialCode: selectedCountry.dialCode,
      minLength: selectedCountry.minLength,
      maxLength: selectedCountry.maxLength,
    )) {
      errorMessage = selectedCountry.iso2 == 'RW'
          ? 'valid_rwanda_phone'
          : 'valid_phone_number';
      notifyListeners();
      return false;
    }
    if (sending) return false;
    sending = true;
    notifyListeners();
    try {
      pendingPhone = e164Phone(
        localDigits,
        countryCode: selectedCountry.dialCode,
      );
      testOtpMode = await _auth.sendOtp(
        phone: pendingPhone,
        role: role,
        termsAccepted: signupTermsAccepted,
        privacyAccepted: signupPrivacyAccepted,
        policyVersion: signupPolicyVersion,
        googleLinkToken: googlePhoneLinkToken,
      );
      _startResendTimer();
      return true;
    } on AuthException catch (e) {
      testOtpMode = false;
      errorMessage = e.message;
      phoneTaken = e.isPhoneTaken;
      userNotFound = e.isUserNotFound;
      return false;
    } catch (_) {
      testOtpMode = false;
      errorMessage = 'could_not_send_code';
      return false;
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  Future<AuthSession?> verifyCode({required AppRole role, String? code}) async {
    errorMessage = null;
    phoneTaken = false;
    final value = (code ?? otpCode).trim();
    if (value.length != 4) {
      errorMessage = 'four_digit_code';
      notifyListeners();
      return null;
    }
    if (verifying) return null;
    verifying = true;
    notifyListeners();
    try {
      final session = await _auth.verifyOtp(
        phone: pendingPhone,
        code: value,
        role: role,
        termsAccepted: signupTermsAccepted,
        privacyAccepted: signupPrivacyAccepted,
        policyVersion: signupPolicyVersion,
        googleLinkToken: googlePhoneLinkToken,
      );
      _clearSignupConsent();
      googlePhoneLinkToken = null;
      return session;
    } on AuthException catch (e) {
      errorMessage = e.message;
      phoneTaken = e.isPhoneTaken;
      return null;
    } catch (_) {
      errorMessage = 'could_not_verify_code';
      return null;
    } finally {
      verifying = false;
      notifyListeners();
    }
  }

  Future<AuthSession?> saveName({
    required String firstName,
    required String lastName,
    String? locale,
  }) async {
    errorMessage = null;
    if (firstName.trim().isEmpty) {
      errorMessage = 'enter_first_name';
      notifyListeners();
      return null;
    }
    if (savingProfile) return null;
    savingProfile = true;
    notifyListeners();
    try {
      return await _auth.updateProfile(
        firstName: firstName,
        lastName: lastName,
        locale: locale,
      );
    } on AuthException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (_) {
      errorMessage = 'could_not_save_name';
      return null;
    } finally {
      savingProfile = false;
      notifyListeners();
    }
  }

  Future<AuthSession?> saveLocale(String locale) async {
    errorMessage = null;
    try {
      return await _auth.updateProfile(locale: locale);
    } on AuthException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'could_not_save_language';
      notifyListeners();
      return null;
    }
  }

  Future<AuthSession?> setAvatarKey(String avatarKey) async {
    errorMessage = null;
    if (savingProfile) return null;
    savingProfile = true;
    notifyListeners();
    try {
      return await _auth.updateProfile(avatarKey: avatarKey);
    } on AuthException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (_) {
      errorMessage = 'could_not_save_avatar';
      return null;
    } finally {
      savingProfile = false;
      notifyListeners();
    }
  }

  Future<AuthSession?> uploadPhoto(String filePath) async {
    errorMessage = null;
    if (savingProfile) return null;
    savingProfile = true;
    notifyListeners();
    try {
      return await _auth.uploadAvatar(filePath);
    } on AuthException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (_) {
      errorMessage = 'could_not_upload_photo';
      return null;
    } finally {
      savingProfile = false;
      notifyListeners();
    }
  }

  Future<void> resend({AppRole? role}) async {
    if (resendInSec > 0 || pendingPhone.isEmpty) return;
    final local = pendingPhone.startsWith(selectedCountry.dialCode)
        ? pendingPhone.substring(selectedCountry.dialCode.length)
        : pendingPhone;
    await sendCode(local, role: role);
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    resendInSec = 20;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendInSec <= 1) {
        timer.cancel();
        resendInSec = 0;
        notifyListeners();
        return;
      }
      resendInSec -= 1;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
