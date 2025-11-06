import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';

/// A compact language selector widget that displays as a dropdown button
/// Perfect for auth pages (login/register) where space is limited
class CompactLanguageSelector extends StatelessWidget {
  final Color? textColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showLabel;

  const CompactLanguageSelector({
    super.key,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.showLabel = true,
  });

  // Map language codes to flag emojis
  static const Map<String, String> languageFlags = {
    'en': '🇬🇧',
    'es': '🇪🇸',
    'fr': '🇫🇷',
    'de': '🇩🇪',
    'zh': '🇨🇳',
    'ar': '🇸🇦',
    'hi': '🇮🇳',
    'pt': '🇵🇹',
    'ja': '🇯🇵',
    'ko': '🇰🇷',
    'it': '🇮🇹',
    'ru': '🇷🇺',
    'nl': '🇳🇱',
    'tr': '🇹🇷',
    'pl': '🇵🇱',
    'vi': '🇻🇳',
  };

  void _showLanguageBottomSheet(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    final currentLocale = languageProvider.locale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.language, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            // Language list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: languageFlags.entries.map((entry) {
                  final code = entry.key;
                  final flag = entry.value;
                  final name = languageProvider.getLanguageName(code);
                  final isSelected = currentLocale == code;

                  return ListTile(
                    leading: Text(flag, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? Colors.blue.shade700 : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.blue.shade700)
                        : null,
                    onTap: () {
                      languageProvider.setLocale(Locale(code, ''));
                      Navigator.pop(context);

                      // Show confirmation snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Text(flag),
                              const SizedBox(width: 8),
                              Text('Language changed to $name'),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentCode = languageProvider.locale.languageCode;
        final currentFlag = languageFlags[currentCode] ?? '🌐';

        return Material(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _showLanguageBottomSheet(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: backgroundColor ?? Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderColor ?? Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentFlag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (showLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      currentCode.toUpperCase(),
                      style: TextStyle(
                        color: textColor ?? Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    color: textColor ?? Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A prominent language selector banner for the top of auth pages
class LanguageBanner extends StatelessWidget {
  const LanguageBanner({super.key});

  void _showLanguageBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          final currentLocale = languageProvider.locale.languageCode;

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.language, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Language',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),
                // Language list
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: CompactLanguageSelector.languageFlags.entries
                        .map((entry) {
                      final code = entry.key;
                      final flag = entry.value;
                      final name = languageProvider.getLanguageName(code);
                      final isSelected = currentLocale == code;

                      return ListTile(
                        leading:
                            Text(flag, style: const TextStyle(fontSize: 28)),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.black87,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: Colors.blue.shade700)
                            : null,
                        onTap: () {
                          languageProvider.setLocale(Locale(code, ''));
                          Navigator.pop(context);

                          // Show confirmation snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Text(flag),
                                  const SizedBox(width: 8),
                                  Text('Language changed to $name'),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final currentCode = languageProvider.locale.languageCode;
        final currentFlag =
            CompactLanguageSelector.languageFlags[currentCode] ?? '🌐';
        final currentName = languageProvider.getLanguageName(currentCode);

        return GestureDetector(
          onTap: () => _showLanguageBottomSheet(context),
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Text(currentFlag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      Text(
                        'Tap to change language',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
