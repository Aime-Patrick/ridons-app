import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/config/api_config.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/app_role.dart';
import '../../../../domain/models/session_user.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required AuthRepository authRepository})
    : _auth = authRepository;

  final AuthRepository _auth;

  String pendingPhone = '';
  String otpCode = '';
  bool sending = false;
  bool verifying = false;
  bool savingProfile = false;
  bool phoneTaken = false;
  bool userNotFound = false;
  String? errorMessage;
  int resendInSec = 0;
  bool signupTermsAccepted = false;
  bool signupPrivacyAccepted = false;
  String signupPolicyVersion = RidonsEnv.policyVersion;

  void setSignupConsent({required bool accepted}) {
    signupTermsAccepted = accepted;
    signupPrivacyAccepted = accepted;
    notifyListeners();
  }

  Timer? _resendTimer;

  String get displayPhone => pendingPhone.isEmpty ? '+250' : pendingPhone;

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
    if (!isValidRwandaLocal(localDigits)) {
      errorMessage = 'valid_rwanda_phone';
      notifyListeners();
      return false;
    }
    if (sending) return false;
    sending = true;
    notifyListeners();
    try {
      pendingPhone = e164Phone(localDigits);
      await _auth.sendOtp(
        phone: pendingPhone,
        role: role,
        termsAccepted: signupTermsAccepted,
        privacyAccepted: signupPrivacyAccepted,
        policyVersion: signupPolicyVersion,
      );
      _startResendTimer();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
      phoneTaken = e.isPhoneTaken;
      userNotFound = e.isUserNotFound;
      return false;
    } catch (_) {
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
      );
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
    await sendCode(pendingPhone.replaceFirst('+250', ''), role: role);
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
