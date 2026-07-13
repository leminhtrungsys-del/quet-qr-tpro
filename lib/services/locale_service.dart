import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide language control. Supports English and Vietnamese.
///
/// Defaults to the device's system locale on first launch (falling back to
/// English if the device language isn't one of our supported locales), and
/// remembers the user's manual choice (via the language toggle in the
/// Scanner app bar) across app restarts using SharedPreferences.
class LocaleService {
  LocaleService._();
  static final LocaleService instance = LocaleService._();

  static const _prefsKey = 'app_locale_code';

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('vi'),
  ];

  /// Notifies [MaterialApp] to rebuild with a new locale. `null` means
  /// "follow system locale" (still constrained to [supportedLocales] via
  /// `localeResolutionCallback`).
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null) {
      locale.value = Locale(code);
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    locale.value = newLocale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newLocale.languageCode);
  }

  /// Toggles between English and Vietnamese — used by the globe icon button.
  Future<void> toggle(BuildContext context) async {
    final current = locale.value ?? Localizations.localeOf(context);
    final next = current.languageCode == 'vi' ? const Locale('en') : const Locale('vi');
    await setLocale(next);
  }
}
