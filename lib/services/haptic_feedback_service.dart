import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// Service for providing haptic feedback and sound effects
/// Requires 'android.permission.VIBRATE' in AndroidManifest.xml (already present)
class HapticFeedbackService {
  static final HapticFeedbackService _instance =
      HapticFeedbackService._internal();

  factory HapticFeedbackService() {
    return _instance;
  }

  HapticFeedbackService._internal();

  // ============================================================================
  // HAPTIC FEEDBACK METHODS
  // ============================================================================

  /// Light haptic feedback - suitable for button taps, selections
  /// Creates a subtle vibration that doesn't distract the user
  static Future<void> lightTap() async {
    try {
      await HapticFeedback.lightImpact();
      AppLogger().debug('✨ Light haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Light haptic failed: $e');
    }
  }

  /// Medium haptic feedback - suitable for confirmations, important actions
  /// Creates a noticeable but not jarring vibration
  static Future<void> mediumTap() async {
    try {
      await HapticFeedback.mediumImpact();
      AppLogger().debug('✨ Medium haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Medium haptic failed: $e');
    }
  }

  /// Heavy haptic feedback - suitable for errors, warnings, critical actions
  /// Creates a strong, attention-grabbing vibration
  static Future<void> heavyTap() async {
    try {
      await HapticFeedback.heavyImpact();
      AppLogger().debug('✨ Heavy haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Heavy haptic failed: $e');
    }
  }

  /// Vibration pattern: short double tap
  /// Useful for "success" feedback
  static Future<void> doubleTap() async {
    try {
      // Two light impacts with small delay
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      AppLogger().debug('✨ Double tap haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Double tap haptic failed: $e');
    }
  }

  /// Vibration pattern: triple tap
  /// Useful for "triple confirmed" or special events
  static Future<void> tripleTap() async {
    try {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
      AppLogger().debug('✨ Triple tap haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Triple tap haptic failed: $e');
    }
  }

  /// Selection changed feedback - subtle notification
  static Future<void> selectionChanged() async {
    try {
      await HapticFeedback.selectionClick();
      AppLogger().debug('✨ Selection changed haptic feedback triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Selection changed haptic failed: $e');
    }
  }

  // ============================================================================
  // COMPOUND FEEDBACK PATTERNS
  // ============================================================================

  /// Success pattern: double medium taps
  /// Call after successful operations (message sent, post created, etc.)
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.mediumImpact();
      AppLogger().debug('✅ Success haptic pattern triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Success pattern failed: $e');
    }
  }

  /// Error pattern: heavy tap followed by light vibration
  /// Call after failed operations (network error, validation error, etc.)
  static Future<void> error() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      await HapticFeedback.lightImpact();
      AppLogger().debug('❌ Error haptic pattern triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Error pattern failed: $e');
    }
  }

  /// Warning pattern: medium tap with slight pause
  /// Call for warnings, alerts, or important notices
  static Future<void> warning() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.mediumImpact();
      AppLogger().debug('⚠️ Warning haptic pattern triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Warning pattern failed: $e');
    }
  }

  /// Notification pattern: single light tap
  /// Call for non-critical notifications, likes, comments, etc.
  static Future<void> notification() async {
    try {
      await HapticFeedback.lightImpact();
      AppLogger().debug('🔔 Notification haptic pattern triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Notification pattern failed: $e');
    }
  }

  /// Long press pattern: sustained vibration effect
  /// Simulated with three quick taps for haptic engine limitation
  static Future<void> longPress() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
      AppLogger().debug('📍 Long press haptic pattern triggered');
    } catch (e) {
      AppLogger().warning('⚠️ Long press pattern failed: $e');
    }
  }

  // ============================================================================
  // FEEDBACK FOR SPECIFIC INTERACTIONS
  // ============================================================================

  /// Call when user taps a button
  /// Subtle feedback to confirm button press
  static Future<void> buttonPress() async => await lightTap();

  /// Call when user submits a form
  /// Medium feedback to confirm action
  static Future<void> formSubmitted() async => await mediumTap();

  /// Call when user likes/favorites something
  /// Light double tap for positive action
  static Future<void> likeAction() async => await doubleTap();

  /// Call when user swipes to dismiss
  /// Light feedback for gesture completion
  static Future<void> swipeDismiss() async => await lightTap();

  /// Call when user scrolls to bottom/top
  /// Light feedback for scroll boundary
  static Future<void> scrollBoundary() async => await selectionChanged();

  /// Call when user enters text
  /// Light feedback for each character input (use sparingly!)
  static Future<void> textInput() async => await selectionChanged();

  /// Call when file/photo upload succeeds
  /// Success pattern for file operations
  static Future<void> uploadSuccess() async => await success();

  /// Call when file/photo upload fails
  /// Error pattern for file operations
  static Future<void> uploadError() async => await error();

  /// Call when user receives a message/notification
  /// Single notification tap
  static Future<void> messageReceived() async => await notification();

  /// Call when user starts recording
  /// Medium tap to confirm recording started
  static Future<void> recordingStart() async => await mediumTap();

  /// Call when user stops recording
  /// Medium tap to confirm recording stopped
  static Future<void> recordingStop() async => await mediumTap();

  /// Call during critical error (app crash, auth failure)
  /// Heavy feedback to alert user
  static Future<void> criticalError() async => await error();
}
