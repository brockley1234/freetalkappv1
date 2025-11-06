import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'utils/app_logger.dart';
import 'services/firebase_messaging_service.dart';
import 'services/theme_service.dart';
import 'services/language_provider.dart';
import 'services/accessibility_service.dart';
import 'config/app_config.dart';
import 'config/app_router.dart';
import 'config/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'services/global_notification_service.dart';

void main() async {
  // Wrap everything in a try-catch to prevent uncaught errors
  try {
    // Ensure Flutter bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();

    // WEB PERFORMANCE: On web, reduce frame rate to reduce rendering load
    if (kIsWeb) {
      // Note: Frame rate is managed by browser, but we can optimize rendering
      debugPrint('🌐 Web platform detected - optimizing rendering performance');
    }

    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase Messaging
    await FirebaseMessagingService().initialize();

    // Initialize Theme Service
    await ThemeService().initialize();

    // Initialize Accessibility Service
    await AccessibilityService().initialize();

    // Print app configuration
    AppConfig.printConfig();

    // Set log level to debug to see all logs (socket, notification, etc.) - only in debug mode
    if (kDebugMode) {
      AppLogger().setLogLevel(LogLevel.debug);
      debugPrint('🔧 Log level set to DEBUG - all logs will be shown');

      // Set a custom error widget builder for better debugging
      ErrorWidget.builder = (FlutterErrorDetails details) {
        debugPrint('❌ Flutter Error: ${details.exception}');
        debugPrint('Stack trace: ${details.stack}');
        return MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'Error: ${details.exception}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        );
      };
    }

    // Set preferred orientations (portrait mode) - only on mobile platforms
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Set system UI overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }

    runApp(const MyApp());
  } catch (e, stackTrace) {
    // Log the error for debugging
    debugPrint('❌ Error during app initialization: $e');
    debugPrint('Stack trace: $stackTrace');

    // Still try to run the app with error handling
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AccessibilityService()),
      ],
      child: Consumer2<LanguageProvider, ThemeService>(
        builder: (context, languageProvider, themeService, child) {
          return MaterialApp.router(
            title: 'FreeTalk',
            debugShowCheckedModeBanner: false,
            // Wire global scaffold key for in-app notifications/snackbars
            scaffoldMessengerKey:
                GlobalNotificationService().scaffoldMessengerKey,
            // Add localization delegates
            locale: languageProvider.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            // Enhanced light theme with consistent branding
            theme: createLightTheme(),
            // Enhanced dark theme - Required for iOS App Store compliance
            darkTheme: createDarkTheme(),
            // Respect system theme preference
            themeMode: themeService.themeMode,
            // Add error builder to catch runtime errors
            builder: (context, widget) {
              // Handle errors gracefully
              if (kDebugMode) {
                ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              errorDetails.exception.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                };
              }
              return widget!;
            },
            // Use GoRouter for deep link support
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
