import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same persistence pattern as [ThemeNotifier] in app_theme.dart — a simple
/// StateNotifier backed by SharedPreferences, no new infra to learn.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const String _localeKey = 'app_locale';
  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');

  LocaleNotifier() : super(english) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code == arabic.languageCode) state = arabic;
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }

  Future<void> toggleLocale() async {
    await setLocale(state == arabic ? english : arabic);
  }

  bool get isArabic => state == arabic;
}
