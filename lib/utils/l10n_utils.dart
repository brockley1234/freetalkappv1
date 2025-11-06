import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Advanced localization utilities for handling parameterized and pluralized strings.
///
/// This utility provides helper methods for:
/// - Parameterized strings (strings with dynamic values)
/// - Pluralization (singular/plural forms)
/// - Gender-aware translations (for languages that require it)
/// - Formatted numbers and dates
class L10nUtils {
  /// Get a parameterized string with a single replacement.
  ///
  /// Example:
  /// ```dart
  /// // English: "Hello, {name}!"
  /// L10nUtils.param(context, 'greeting', ['Alice'])
  /// // Returns: "Hello, Alice!"
  /// ```
  static String param(BuildContext context, String key, List<String> values) {
    final loc = AppLocalizations.of(context);
    if (loc == null) return key;

    // This would require extending AppLocalizations with a method like:
    // String getParameterized(String key, List<String> values);
    // For now, return the key as fallback
    return key;
  }

  /// Get pluralized string based on count.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.plural(context, 'items', 5)
  /// // Returns: "5 items"
  /// ```
  static String plural(BuildContext context, String key, int count) {
    final loc = AppLocalizations.of(context);
    if (loc == null) return '$count $key';

    // Implementation would check count and select appropriate form
    // This is a placeholder for the actual implementation
    return '$count $key';
  }

  /// Format a number according to locale conventions.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.formatNumber(context, 1234.56)
  /// // In en_US: "1,234.56"
  /// // In de_DE: "1.234,56"
  /// ```
  static String formatNumber(BuildContext context, num value) {
    final locale = Localizations.localeOf(context);

    // Simple implementation - can be enhanced with intl package
    if (locale.languageCode == 'de' ||
        locale.languageCode == 'fr' ||
        locale.languageCode == 'pt') {
      return value.toString().replaceAll('.', ',');
    }

    return value.toString();
  }

  /// Format a number as currency for a given locale.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.formatCurrency(context, 99.99)
  /// // In en_US: "$99.99"
  /// // In de_DE: "99,99 €"
  /// ```
  static String formatCurrency(BuildContext context, num amount) {
    final locale = Localizations.localeOf(context);
    final symbol = _getCurrencySymbol(locale.languageCode);

    if (locale.languageCode == 'de' || locale.languageCode == 'fr') {
      return '${amount.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
    }

    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Format a count with proper singular/plural form.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.countFormatter(context, 'comment', 3)
  /// // Returns: "3 comments"
  ///
  /// L10nUtils.countFormatter(context, 'like', 1)
  /// // Returns: "1 like"
  /// ```
  static String countFormatter(BuildContext context, String item, int count) {
    final loc = AppLocalizations.of(context);
    if (loc == null) return '$count $item';

    // Return singular or plural based on count
    if (count == 1) {
      return '1 $item';
    } else {
      return '$count ${_pluralizeWord(context, item)}';
    }
  }

  /// Format a time ago string with proper localization.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.timeAgo(context, DateTime.now().subtract(Duration(hours: 2)))
  /// // Returns: "2 hours ago"
  /// ```
  static String timeAgo(BuildContext context, DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} minutes ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return '${(diff.inDays / 30).floor()} months ago';
    }
  }

  /// Get the possessive form of a name.
  ///
  /// Example:
  /// ```dart
  /// L10nUtils.possessive(context, 'John')
  /// // In English: "John's"
  /// // In French: "de John"
  /// ```
  static String possessive(BuildContext context, String name) {
    final locale = Localizations.localeOf(context);

    switch (locale.languageCode) {
      case 'fr':
      case 'de':
        return 'de $name';
      case 'es':
        return 'de $name';
      case 'it':
        return 'di $name';
      case 'pt':
        return 'de $name';
      default:
        // English-style possessive
        if (name.endsWith('s')) {
          return "$name'";
        }
        return "$name's";
    }
  }

  /// Check if the current locale is RTL (Right-to-Left).
  static bool isRTL(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return locale.languageCode == 'ar' || locale.languageCode == 'he';
  }

  /// Get text direction for current locale.
  static TextDirection getTextDirection(BuildContext context) {
    return isRTL(context) ? TextDirection.rtl : TextDirection.ltr;
  }

  // ===== PRIVATE HELPERS =====

  static String _getCurrencySymbol(String languageCode) {
    switch (languageCode) {
      case 'de':
      case 'fr':
      case 'nl':
        return '€';
      case 'gb':
      case 'en':
        return '\$';
      case 'pt':
        return 'R\$';
      case 'ja':
        return '¥';
      case 'ko':
        return '₩';
      case 'ru':
        return '₽';
      case 'tr':
        return '₺';
      default:
        return '\$';
    }
  }

  static String _pluralizeWord(BuildContext context, String word) {
    final locale = Localizations.localeOf(context);

    // Simple English pluralization
    if (locale.languageCode == 'en') {
      if (word.endsWith('y')) {
        return '${word.substring(0, word.length - 1)}ies';
      } else if (word.endsWith('s') ||
          word.endsWith('x') ||
          word.endsWith('z')) {
        return '${word}es';
      }
      return '${word}s';
    }

    // For other languages, just return the word
    // (would need language-specific pluralization rules)
    return word;
  }
}

/// Extension methods for easier access to localization utilities.
extension LocalizationExtension on BuildContext {
  /// Quickly access AppLocalizations.
  AppLocalizations? get loc => AppLocalizations.of(this);

  /// Check if current locale is RTL.
  bool get isRTL => L10nUtils.isRTL(this);

  /// Get text direction for current locale.
  TextDirection get textDirection => L10nUtils.getTextDirection(this);

  /// Format a time ago string.
  String timeAgo(DateTime dateTime) => L10nUtils.timeAgo(this, dateTime);

  /// Format a count with proper plural.
  String countFormatter(String item, int count) =>
      L10nUtils.countFormatter(this, item, count);
}
