import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService extends ChangeNotifier {
  static final AccessibilityService _instance =
      AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  bool _screenReaderEnabled = false;
  bool _highContrastEnabled = false;
  bool _largeTextEnabled = false;
  bool _reduceMotionEnabled = false;
  bool _isInitialized = false;

  // Getters
  bool get screenReaderEnabled => _screenReaderEnabled;
  bool get highContrastEnabled => _highContrastEnabled;
  bool get largeTextEnabled => _largeTextEnabled;
  bool get reduceMotionEnabled => _reduceMotionEnabled;
  bool get isInitialized => _isInitialized;

  // Text scale factor based on large text setting
  double get textScaleFactor => _largeTextEnabled ? 1.2 : 1.0;

  // Animation duration based on reduce motion setting
  Duration get animationDuration => _reduceMotionEnabled
      ? const Duration(milliseconds: 0)
      : const Duration(milliseconds: 300);

  // Initialize from SharedPreferences
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _screenReaderEnabled =
          prefs.getBool('accessibility_screen_reader') ?? false;
      _highContrastEnabled =
          prefs.getBool('accessibility_high_contrast') ?? false;
      _largeTextEnabled = prefs.getBool('accessibility_large_text') ?? false;
      _reduceMotionEnabled =
          prefs.getBool('accessibility_reduce_motion') ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing accessibility service: $e');
      _isInitialized =
          true; // Still mark as initialized to avoid infinite retries
    }
  }

  // Update settings
  Future<void> setScreenReaderEnabled(bool enabled) async {
    if (_screenReaderEnabled == enabled) return;
    _screenReaderEnabled = enabled;
    await _saveSetting('accessibility_screen_reader', enabled);
    notifyListeners();
  }

  Future<void> setHighContrastEnabled(bool enabled) async {
    if (_highContrastEnabled == enabled) return;
    _highContrastEnabled = enabled;
    await _saveSetting('accessibility_high_contrast', enabled);
    notifyListeners();
  }

  Future<void> setLargeTextEnabled(bool enabled) async {
    if (_largeTextEnabled == enabled) return;
    _largeTextEnabled = enabled;
    await _saveSetting('accessibility_large_text', enabled);
    notifyListeners();
  }

  Future<void> setReduceMotionEnabled(bool enabled) async {
    if (_reduceMotionEnabled == enabled) return;
    _reduceMotionEnabled = enabled;
    await _saveSetting('accessibility_reduce_motion', enabled);
    notifyListeners();
  }

  // Update from server settings
  Future<void> updateFromServerSettings(Map<String, dynamic> settings) async {
    final screenReader = settings['screenReaderEnabled'] as bool?;
    final highContrast = settings['highContrastEnabled'] as bool?;
    final largeText = settings['largeTextEnabled'] as bool?;
    final reduceMotion = settings['reduceMotionEnabled'] as bool?;

    bool changed = false;

    if (screenReader != null && screenReader != _screenReaderEnabled) {
      _screenReaderEnabled = screenReader;
      changed = true;
    }
    if (highContrast != null && highContrast != _highContrastEnabled) {
      _highContrastEnabled = highContrast;
      changed = true;
    }
    if (largeText != null && largeText != _largeTextEnabled) {
      _largeTextEnabled = largeText;
      changed = true;
    }
    if (reduceMotion != null && reduceMotion != _reduceMotionEnabled) {
      _reduceMotionEnabled = reduceMotion;
      changed = true;
    }

    if (changed) {
      await _saveAllSettings();
      notifyListeners();
    }
  }

  // Helper method to save individual setting
  Future<void> _saveSetting(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e) {
      debugPrint('Error saving accessibility setting $key: $e');
    }
  }

  // Save all current settings
  Future<void> _saveAllSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('accessibility_screen_reader', _screenReaderEnabled);
      await prefs.setBool('accessibility_high_contrast', _highContrastEnabled);
      await prefs.setBool('accessibility_large_text', _largeTextEnabled);
      await prefs.setBool('accessibility_reduce_motion', _reduceMotionEnabled);
    } catch (e) {
      debugPrint('Error saving all accessibility settings: $e');
    }
  }

  // Get high contrast theme colors
  Color getHighContrastColor(Color normalColor, Color highContrastColor) {
    return _highContrastEnabled ? highContrastColor : normalColor;
  }

  // Get accessible text style
  TextStyle getAccessibleTextStyle(TextStyle baseStyle) {
    return baseStyle.copyWith(
      fontSize: baseStyle.fontSize! * textScaleFactor,
    );
  }

  // Check if animations should be disabled
  bool get shouldDisableAnimations => _reduceMotionEnabled;

  // Get semantic label for screen readers
  String getSemanticLabel(String baseLabel, {String? screenReaderLabel}) {
    if (_screenReaderEnabled && screenReaderLabel != null) {
      return screenReaderLabel;
    }
    return baseLabel;
  }
}
