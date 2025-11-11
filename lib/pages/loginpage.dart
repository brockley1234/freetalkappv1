import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'registerpage.dart';
import 'forgot_password_page.dart';
import 'recover_pin_page.dart';
import '../services/api_service.dart';
import '../services/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/compact_language_selector.dart';
import '../auth_wrapper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinCodeController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePin = true;
  Timer? _emailDebounce;

  @override
  void initState() {
    super.initState();
    _loadRememberedCredentials();
    // Keep stored email updated when Remember Me is enabled
    _emailController.addListener(() async {
      if (_rememberMe) {
        _emailDebounce?.cancel();
        _emailDebounce = Timer(const Duration(milliseconds: 500), () async {
          final currentEmail = _emailController.text.trim();
          if (currentEmail.isNotEmpty) {
            await ApiService.storeRememberedCredentials(email: currentEmail);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.dispose();
    _pinCodeController.dispose();
    super.dispose();
  }

  // Load remembered credentials on page load
  Future<void> _loadRememberedCredentials() async {
    final remembered = await ApiService.getRememberedCredentials();
    final isRememberMeEnabled = await ApiService.isRememberMeEnabled();

    if (isRememberMeEnabled && remembered['email'] != null) {
      setState(() {
        _emailController.text = remembered['email']!;
        _rememberMe = true;
      });
    }
  }

  void _toggleRememberMe(bool? value) {
    final newValue = value ?? false;
    setState(() {
      _rememberMe = newValue;
    });
    // Persist preference immediately
    if (newValue) {
      final email = _emailController.text.trim();
      if (email.isNotEmpty) {
        ApiService.storeRememberedCredentials(email: email);
      }
    } else {
      ApiService.clearRememberedCredentials();
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await ApiService.login(
          email: _emailController.text.trim(),
          pinCode: _pinCodeController.text,
        );

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Handle Remember Me functionality
          if (_rememberMe) {
            // Save credentials for next login
            await ApiService.storeRememberedCredentials(
              email: _emailController.text.trim(),
              name: result['data']['user']?['name'],
            );
          } else {
            // Clear any previously saved credentials
            await ApiService.clearRememberedCredentials();
          }

          if (mounted) {
            // Navigate to home page by pushing a new AuthWrapper
            // This forces AuthWrapper to re-check authentication and initialize services
            // Using pushAndRemoveUntil ensures we can't go back to login page
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AuthWrapper(),
              ),
              (route) => false, // Remove all previous routes
            );
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Login failed. Please try again.';
        String? actionableHint;

        if (e is ApiException) {
          errorMessage = e.userFriendlyMessage;

          // Add actionable hints based on error
          if (e.statusCode == 401) {
            actionableHint = 'Check your email and PIN, or try "Forgot PIN"';
          } else if (e.statusCode == 429) {
            actionableHint = 'Too many attempts. Please wait a few minutes';
          } else if (e.statusCode >= 500) {
            actionableHint = 'Server issue. Please try again in a moment';
          }
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (dialogContext) {
              final dialogTheme = Theme.of(dialogContext);
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: dialogTheme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(child: Text('Login Failed')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorMessage,
                      style: dialogTheme.textTheme.bodyLarge,
                    ),
                    if (actionableHint != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dialogTheme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: dialogTheme.colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                actionableHint,
                                style: dialogTheme.textTheme.bodyMedium?.copyWith(
                                  color: dialogTheme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (actionableHint?.contains('Forgot PIN') == true)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _navigateToForgotPassword();
                      },
                      child: const Text('Reset PIN'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  void _navigateToForgotPassword() {
    // Show options dialog
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text('Choose how you want to recover your PIN:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecoverPinPage(),
                ),
              );
            },
            child: const Text('Use Security Question'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecoverPinPage(method: 'email'),
                ),
              );
            },
            child: const Text('Send Email'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ForgotPasswordPage(),
                ),
              );
            },
            child: const Text('Reset with Old PIN'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    // Wrap in Consumer to rebuild when language changes
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final localizations = AppLocalizations.of(context);

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gradient Header with Language Selector
                  Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: isSmallScreen ? 220 : 280,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              localizations?.appName ?? ApiService.appName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 28 : 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 16 : 0),
                              child: Text(
                                localizations?.connectWithFriends ??
                                    'Connect with friends and share your thoughts',
                                style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Language selector button in top-right corner
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: CompactLanguageSelector(
                          textColor: Colors.white,
                          backgroundColor: Colors.transparent,
                          borderColor: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                  // Form content
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: EdgeInsets.all(horizontalPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: isSmallScreen ? 20 : 32),
                            // Login Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email Field
                                  Semantics(
                                    label: 'Email address input field',
                                    hint: 'Enter your email address',
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email,
                                        AutofillHints.username,
                                      ],
                                      textInputAction: TextInputAction.next,
                                      decoration: InputDecoration(
                                        labelText:
                                            localizations?.email ?? 'Email',
                                        hintText: 'e.g., user@example.com',
                                        helperText:
                                            'Enter a valid email address',
                                        prefixIcon:
                                            const Icon(Icons.email_outlined),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your email';
                                        }
                                        if (!RegExp(
                                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                        ).hasMatch(value)) {
                                          return 'Please enter a valid email (e.g., user@example.com)';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // PIN Code Field
                                  Semantics(
                                    label: '4-digit PIN input field',
                                    hint: 'Enter your 4-digit PIN',
                                    child: TextFormField(
                                      controller: _pinCodeController,
                                      keyboardType: TextInputType.number,
                                        textInputAction: TextInputAction.done,
                                        maxLength: 4,
                                        obscureText: _obscurePin,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(4),
                                        ],
                                      onFieldSubmitted: (_) => _handleLogin(),
                                      decoration: InputDecoration(
                                        labelText:
                                            localizations?.fourDigitPin ??
                                                '4-Digit PIN',
                                        hintText: 'Enter your PIN',
                                        helperText:
                                            'The 4-digit PIN you chose during registration',
                                        counterText:
                                            '', // Hide character counter
                                        prefixIcon:
                                            const Icon(Icons.pin_outlined),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePin
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePin = !_obscurePin;
                                              });
                                            },
                                          ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.outline,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                            color: theme.colorScheme.primary,
                                            width: 2,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: theme.colorScheme.surfaceContainerHighest,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your PIN';
                                        }
                                        if (value.length != 4) {
                                          return 'PIN must be exactly 4 digits';
                                        }
                                        if (!RegExp(r'^\d{4}$')
                                            .hasMatch(value)) {
                                          return 'PIN must contain only numbers';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Remember me and Forgot password
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Checkbox(
                                              value: _rememberMe,
                                              onChanged: _toggleRememberMe,
                                            ),
                                            Flexible(
                                              child: Text(
                                                localizations?.rememberMe ??
                                                    'Remember me',
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Flexible(
                                        child: TextButton(
                                          onPressed: _navigateToForgotPassword,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                          ),
                                          child: Text(
                                            localizations?.forgotPassword ??
                                                'Forgot PIN?',
                                            style: TextStyle(
                                              color: theme.colorScheme.primary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Login Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: theme.colorScheme.onPrimary,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              localizations?.login ?? 'Login',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onPrimary,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Sign up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "${localizations?.dontHaveAccount ?? "Don't have an account?"} ",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _navigateToSignUp,
                                  child: Text(
                                    localizations?.signUp ?? 'Sign Up',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
