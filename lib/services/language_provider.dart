import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en', '');
  static const String _languageKey = 'selected_language';

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _locale = Locale(languageCode, '');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
    } catch (e) {
      debugPrint('Error saving language: $e');
    }
  }

  // Get language name for display
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'zh':
        return '中文';
      case 'ar':
        return 'العربية';
      case 'hi':
        return 'हिन्दी';
      case 'pt':
        return 'Português';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'it':
        return 'Italiano';
      case 'ru':
        return 'Русский';
      case 'nl':
        return 'Nederlands';
      case 'tr':
        return 'Türkçe';
      case 'pl':
        return 'Polski';
      case 'vi':
        return 'Tiếng Việt';
      default:
        return 'English';
    }
  }

  // Get native language name
  String getNativeLanguageName(Locale locale) {
    return getLanguageName(locale.languageCode);
  }
}
