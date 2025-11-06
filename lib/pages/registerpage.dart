import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:go_router/go_router.dart'; // Not needed after aligning navigation with AuthWrapper
import 'terms_of_service_page.dart';
import 'privacy_policy_page.dart';
import '../services/api_service.dart';
import '../services/language_provider.dart';
import '../widgets/compact_language_selector.dart';
import '../auth_wrapper.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _confirmPinCodeController = TextEditingController();
  final _securityAnswerController = TextEditingController();
  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  // Security question dropdown
  String? _selectedSecurityQuestion;
  final List<String> _securityQuestions = [
    "What is your mother's maiden name?",
    "What was the name of your first pet?",
    "What city were you born in?",
    "What is your favorite book?",
    "What was your childhood nickname?",
    "What is the name of your favorite teacher?",
    "What street did you grow up on?",
    "What is your favorite movie?"
  ];

  // Real-time validation states
  String? _nameError;
  String? _emailError;
  String? _pinError;
  bool _emailTouched = false;
  bool _nameTouched = false;
  bool _pinTouched = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _pinCodeController.dispose();
    _confirmPinCodeController.dispose();
    _securityAnswerController.dispose();
    super.dispose();
  }

  void _toggleAcceptTerms(bool? value) {
    setState(() {
      _acceptTerms = value ?? false;
    });
  }

  void _validateName(String value) {
    if (!_nameTouched) {
      setState(() => _nameTouched = true);
    }

    setState(() {
      if (value.isEmpty) {
        _nameError = null; // Don't show error on empty until form submit
      } else if (value.trim().length < 2) {
        _nameError = 'Name must be at least 2 characters';
      } else if (value.trim().length > 50) {
        _nameError = 'Name cannot exceed 50 characters';
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
        _nameError = 'Only letters and spaces allowed';
      } else {
        _nameError = null;
      }
    });
  }

  void _validateEmail(String value) {
    if (!_emailTouched) {
      setState(() => _emailTouched = true);
    }

    setState(() {
      if (value.isEmpty) {
        _emailError = null; // Don't show error on empty until form submit
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        _emailError = 'Please enter a valid email';
      } else {
        _emailError = null;
      }
    });
  }

  void _validatePin(String value) {
    if (!_pinTouched) {
      setState(() => _pinTouched = true);
    }

    setState(() {
      if (value.isEmpty) {
        _pinError = null; // Don't show error on empty until form submit
      } else if (value.length != 4) {
        _pinError = 'PIN must be exactly 4 digits';
      } else if (!RegExp(r'^\d{4}$').hasMatch(value)) {
        _pinError = 'PIN must contain only numbers';
      } else {
        _pinError = null;
      }
    });
  }

  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the terms and conditions'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await ApiService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim().toLowerCase(),
          pinCode: _pinCodeController.text,
          securityQuestion: _selectedSecurityQuestion!,
          securityAnswer: _securityAnswerController.text.trim(),
        );

        // If we get here, the request succeeded (status 2xx)
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          // Registration successful - navigate to home by refreshing AuthWrapper
          // This allows AuthWrapper to properly initialize socket connections
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const AuthWrapper(),
              ),
              (route) => false,
            );
          }
        } else {
          // Handle unexpected response format
          throw ApiException(
            statusCode: 500,
            message:
                result['message'] ?? 'Registration failed. Please try again.',
          );
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        String errorMessage = 'Registration failed. Please try again.';
        bool isConflict = false;

        if (e is ApiException) {
          errorMessage = e.userFriendlyMessage;
          isConflict = e.statusCode == 409;
        }

        // Show error dialog for better visibility
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isConflict ? Icons.info_outline : Icons.error_outline,
                  color: isConflict ? Colors.orange : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(isConflict
                    ? 'Account Already Exists'
                    : 'Registration Failed'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (isConflict) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'If this is your account:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Try logging in instead'),
                    const Text('• Use "Forgot Password" if needed'),
                  ] else ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Please ensure:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Name contains only letters and spaces'),
                    const Text('• Email is in valid format'),
                    const Text('• PIN is exactly 4 digits'),
                  ],
                ],
              ),
            ),
            actions: [
              if (isConflict)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    _navigateToLogin(); // Go to login page
                  },
                  child: const Text('Go to Login'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isConflict ? 'Cancel' : 'OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    // Wrap in Consumer to rebuild when language changes
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final isFormReady = _acceptTerms &&
            _nameController.text.trim().length >= 2 &&
            _emailController.text.trim().isNotEmpty &&
            _pinCodeController.text.length == 4 &&
            _confirmPinCodeController.text == _pinCodeController.text &&
            _selectedSecurityQuestion != null &&
            _securityAnswerController.text.trim().length >= 2;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gradient Header with Back Button and Language Selector
                  SizedBox(
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: isSmallScreen ? 200 : 250,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade400,
                                Colors.purple.shade400
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
                                'Join Reel Talk',
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
                                  'Create an account to start connecting',
                                  style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Back button
                        Positioned(
                          top: 8,
                          left: 8,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white),
                            onPressed: _navigateToLogin,
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
                            SizedBox(height: isSmallScreen ? 16 : 24),
                            // Registration Form
                            Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                children: [
                                  // Name Field
                                  Semantics(
                                    label: 'Full name input field',
                                    hint: 'Enter your full name',
                                    child: TextFormField(
                                      controller: _nameController,
                                      keyboardType: TextInputType.name,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      autofillHints: const [AutofillHints.name],
                                      textInputAction: TextInputAction.next,
                                      onChanged: _validateName,
                                      decoration: InputDecoration(
                                        labelText: 'Full Name',
                                        hintText: 'Enter your full name',
                                        helperText: _nameError ??
                                            'Letters and spaces only (2-50 characters)',
                                        helperStyle: TextStyle(
                                          color: _nameError != null
                                              ? Colors.red
                                              : null,
                                        ),
                                        prefixIcon:
                                            const Icon(Icons.person_outline),
                                        suffixIcon: _nameTouched &&
                                                _nameError == null &&
                                                _nameController.text.isNotEmpty
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your full name';
                                        }
                                        if (value.trim().length < 2) {
                                          return 'Name must be at least 2 characters';
                                        }
                                        if (value.trim().length > 50) {
                                          return 'Name cannot exceed 50 characters';
                                        }
                                        if (!RegExp(r'^[a-zA-Z\s]+$')
                                            .hasMatch(value)) {
                                          return 'Name can only contain letters and spaces';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Email Field
                                  Semantics(
                                    label: 'Email address input field',
                                    hint: 'Enter your email address',
                                    child: TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [
                                        AutofillHints.email
                                      ],
                                      textInputAction: TextInputAction.next,
                                      onChanged: _validateEmail,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'e.g., user@example.com',
                                        helperText: _emailError ??
                                            'Enter a valid email address',
                                        helperStyle: TextStyle(
                                          color: _emailError != null
                                              ? Colors.red
                                              : null,
                                        ),
                                        prefixIcon:
                                            const Icon(Icons.email_outlined),
                                        suffixIcon: _emailTouched &&
                                                _emailError == null &&
                                                _emailController.text.isNotEmpty
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : null,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
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
                                  // 4-Digit PIN Field
                                  Semantics(
                                    label: '4-digit PIN input field',
                                    hint:
                                        'Create a 4-digit PIN for authentication',
                                    child: TextFormField(
                                      controller: _pinCodeController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      maxLength: 4,
                                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      obscureText: _obscurePin,
                                      onChanged: _validatePin,
                                      decoration: InputDecoration(
                                        labelText: '4-Digit PIN',
                                        hintText: 'e.g., 1234',
                                        helperText: _pinError ??
                                            'Choose any 4 digits for login authentication',
                                        helperStyle: TextStyle(
                                          color: _pinError != null
                                              ? Colors.red
                                              : null,
                                        ),
                                        counterText:
                                            '', // Hide character counter
                                        prefixIcon:
                                            const Icon(Icons.pin_outlined),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_pinTouched && _pinError == null && _pinCodeController.text.length == 4)
                                              const Icon(Icons.check_circle, color: Colors.green),
                                            IconButton(
                                              icon: Icon(
                                                _obscurePin ? Icons.visibility_off : Icons.visibility,
                                              ),
                                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                            ),
                                          ],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter a 4-digit PIN';
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
                                  // Confirm PIN Field
                                  Semantics(
                                    label: 'Confirm PIN input field',
                                    hint: 'Re-enter your 4-digit PIN',
                                    child: TextFormField(
                                      controller: _confirmPinCodeController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      maxLength: 4,
                                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      obscureText: _obscureConfirmPin,
                                      decoration: InputDecoration(
                                        labelText: 'Confirm PIN',
                                        hintText: 'Re-enter your PIN',
                                        helperText: 'Must match your PIN above',
                                        counterText:
                                            '', // Hide character counter
                                        prefixIcon:
                                            const Icon(Icons.pin_outlined),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                                          ),
                                          onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please confirm your PIN';
                                        }
                                        if (value != _pinCodeController.text) {
                                          return 'PINs do not match';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Security Question Section Header
                                  const Text(
                                    'Security Question',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'This will help you recover your PIN if you forget it',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Security Question Dropdown
                                  SizedBox(
                                    width: double.infinity,
                                    child: Semantics(
                                      label: 'Security question dropdown',
                                      hint: 'Select a security question',
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _selectedSecurityQuestion,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: 'Security Question',
                                          hintText: 'Select a question',
                                          prefixIcon: const Icon(Icons.security),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: Colors.grey.shade300),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: Colors.blue),
                                          ),
                                          filled: true,
                                          fillColor: Colors.grey.shade50,
                                        ),
                                        items: _securityQuestions
                                            .map((String question) {
                                          return DropdownMenuItem<String>(
                                            value: question,
                                            child: Text(
                                              question,
                                              style:
                                                  const TextStyle(fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            _selectedSecurityQuestion = newValue;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please select a security question';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Security Answer Field
                                  Semantics(
                                    label: 'Security answer input field',
                                    hint:
                                        'Enter your answer to the security question',
                                    child: TextFormField(
                                      controller: _securityAnswerController,
                                      textInputAction: TextInputAction.done,
                                      decoration: InputDecoration(
                                        labelText: 'Security Answer',
                                        hintText: 'Enter your answer',
                                        helperText:
                                            'Remember this answer to recover your PIN',
                                        prefixIcon:
                                            const Icon(Icons.question_answer),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          borderSide: const BorderSide(
                                              color: Colors.blue),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please enter your security answer';
                                        }
                                        if (value.trim().length < 2) {
                                          return 'Answer must be at least 2 characters';
                                        }
                                        if (value.trim().length > 100) {
                                          return 'Answer cannot exceed 100 characters';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Terms and Conditions
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _acceptTerms,
                                        onChanged: _toggleAcceptTerms,
                                        activeColor: Colors.blue,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 12),
                                          child: RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                              children: [
                                                const TextSpan(
                                                    text: 'I agree to the '),
                                                TextSpan(
                                                  text: 'Terms & Conditions',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  recognizer:
                                                      TapGestureRecognizer()
                                                        ..onTap = () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const TermsOfServicePage(),
                                                            ),
                                                          );
                                                        },
                                                ),
                                                const TextSpan(text: ' and '),
                                                TextSpan(
                                                  text: 'Privacy Policy',
                                                  style: const TextStyle(
                                                    color: Colors.blue,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                  recognizer:
                                                      TapGestureRecognizer()
                                                        ..onTap = () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const PrivacyPolicyPage(),
                                                            ),
                                                          );
                                                        },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Register Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: (_isLoading || !isFormReady) ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Login link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Already have an account? ",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                TextButton(
                                  onPressed: _navigateToLogin,
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.blue,
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
