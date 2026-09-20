import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_role.dart';

class PrefsStore {
  static const _onboarded = 'ridons.onboarded';
  static const _role = 'ridons.role';
  static const _notifRides = 'ridons.notif.rides';
  static const _notifOffers = 'ridons.notif.offers';
  static const _notifSafety = 'ridons.notif.safety';
  static const _notifBadge = 'ridons.notif.badge';
  static const _emergency = 'ridons.emergency.contacts';
  static const _themeMode = 'ridons.themeMode';

  Future<bool> isOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboarded) ?? false;
  }

  Future<void> setOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboarded, true);
  }

  Future<AppRole?> readRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_role);
    return switch (raw) {
      'driver' => AppRole.driver,
      'passenger' => AppRole.passenger,
      _ => null,
    };
  }

  Future<void> setRole(AppRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_role, role.name);
  }

  Future<bool> rideNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifRides) ?? true;
  }

  Future<bool> offerNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifOffers) ?? true;
  }

  Future<bool> safetyNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifSafety) ?? true;
  }

  Future<void> setRideNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifRides, value);
  }

  Future<void> setOfferNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifOffers, value);
  }

  Future<void> setSafetyNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifSafety, value);
  }

  Future<int> notificationBadge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_notifBadge) ?? 2;
  }

  Future<void> clearNotificationBadge() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifBadge, 0);
  }

  Future<List<String>> emergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_emergency) ?? const [];
  }

  Future<void> setEmergencyContacts(List<String> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_emergency, contacts);
  }

  Future<ThemeMode> readThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_themeMode)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeMode,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }
}
