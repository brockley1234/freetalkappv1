import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:freetalk/l10n/app_localizations.dart';
import 'package:freetalk/services/language_provider.dart';

/// Test helper to create a MaterialApp with proper localization and Provider setup
/// Use this wrapper for all widget tests that need AppLocalizations
class TestMaterialApp extends StatelessWidget {
  final Widget child;
  final Locale locale;

  const TestMaterialApp({
    super.key,
    required this.child,
    this.locale = const Locale('en'),
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
          Locale('fr'),
        ],
        home: child,
      ),
    );
  }
}

/// Helper to wrap a widget with proper test setup
Widget testWidget(Widget widget) {
  return TestMaterialApp(child: widget);
}

/// Helper to create a scaffold with proper localization
Widget testScaffoldWidget(Widget Function(BuildContext) builder) {
  return TestMaterialApp(
    child: Builder(
      builder: (context) => Scaffold(
        body: builder(context),
      ),
    ),
  );
}
