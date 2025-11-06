import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../l10n/app_localizations.dart';

class LanguageSelectionPage extends StatelessWidget {
  const LanguageSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final l10n = AppLocalizations.of(context)!;

    final languages = [
      {'code': 'en', 'flag': '🇬🇧'},
      {'code': 'es', 'flag': '🇪🇸'},
      {'code': 'fr', 'flag': '🇫🇷'},
      {'code': 'de', 'flag': '🇩🇪'},
      {'code': 'zh', 'flag': '🇨🇳'},
      {'code': 'ar', 'flag': '🇸🇦'},
      {'code': 'hi', 'flag': '🇮🇳'},
      {'code': 'pt', 'flag': '🇵🇹'},
      {'code': 'ja', 'flag': '🇯🇵'},
      {'code': 'ko', 'flag': '🇰🇷'},
      {'code': 'it', 'flag': '🇮🇹'},
      {'code': 'ru', 'flag': '🇷🇺'},
      {'code': 'nl', 'flag': '🇳🇱'},
      {'code': 'tr', 'flag': '🇹🇷'},
      {'code': 'pl', 'flag': '🇵🇱'},
      {'code': 'vi', 'flag': '🇻🇳'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changeLanguage),
        elevation: 0,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: languages.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final language = languages[index];
          final languageCode = language['code'] as String;
          final flag = language['flag'] as String;
          final isSelected =
              languageProvider.locale.languageCode == languageCode;

          return ListTile(
            leading: Text(
              flag,
              style: const TextStyle(fontSize: 32),
            ),
            title: Text(
              languageProvider.getLanguageName(languageCode),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(context).primaryColor : null,
              ),
            ),
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  )
                : null,
            onTap: () {
              languageProvider.setLocale(Locale(languageCode, ''));
              // Show a snackbar to confirm the change
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${languageProvider.getLanguageName(languageCode)} selected',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
