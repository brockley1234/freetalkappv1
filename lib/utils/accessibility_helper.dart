import 'package:flutter/material.dart';

/// Helper class for accessibility labels and semantic descriptions
///
/// This class provides consistent semantic labels across the app
/// to ensure compatibility with screen readers like VoiceOver (iOS)
/// and TalkBack (Android).
class AccessibilityHelper {
  // Avatar/Profile Picture Labels
  static String avatarLabel(String userName) {
    return '$userName profile picture';
  }

  static String avatarButtonLabel(String userName) {
    return 'View $userName profile';
  }

  // Post Action Labels
  static String likeButtonLabel({int? count, bool isLiked = false}) {
    String label = 'Like';
    if (count != null && count > 0) {
      label = 'Like, $count likes';
    }
    if (isLiked) {
      label = '$label, already liked';
    }
    return label;
  }

  static String reactButtonLabel({int? count, bool hasReacted = false}) {
    String label = 'React';
    if (count != null && count > 0) {
      label = 'React, $count reactions';
    }
    if (hasReacted) {
      label = '$label, you reacted';
    }
    return label;
  }

  static String commentButtonLabel(int count) {
    if (count == 0) {
      return 'Comment';
    } else if (count == 1) {
      return 'Comment, 1 comment';
    } else {
      return 'Comment, $count comments';
    }
  }

  static String shareButtonLabel() {
    return 'Share post';
  }

  // Media Labels
  static String postImageLabel(String userName,
      {int? imageIndex, int? totalImages}) {
    if (imageIndex != null && totalImages != null && totalImages > 1) {
      return 'Photo ${imageIndex + 1} of $totalImages posted by $userName';
    }
    return 'Photo posted by $userName';
  }

  static String postVideoLabel(String userName) {
    return 'Video posted by $userName';
  }

  static String profilePhotoLabel(String userName) {
    return '$userName profile photo';
  }

  // Navigation Labels
  static String tabLabel(String tabName, {bool isSelected = false}) {
    String label = '$tabName tab';
    if (isSelected) {
      label = '$label, selected';
    }
    return label;
  }

  static String backButtonLabel() {
    return 'Go back';
  }

  static String closeButtonLabel() {
    return 'Close';
  }

  // Message Labels
  static String messageLabel(
      String senderName, String message, DateTime timestamp) {
    final timeAgo = _getTimeAgo(timestamp);
    return 'Message from $senderName, $timeAgo: $message';
  }

  static String voiceMessageLabel(String senderName, Duration? duration) {
    final durationText =
        duration != null ? '${duration.inSeconds} seconds' : 'unknown duration';
    return 'Voice message from $senderName, $durationText';
  }

  // Status Labels
  static String verifiedBadgeLabel(String userName) {
    return '$userName is verified';
  }

  static String premiumBadgeLabel(String userName) {
    return '$userName is a premium member';
  }

  // Form Input Labels
  static String textFieldHint(String fieldName) {
    return 'Enter $fieldName';
  }

  static String searchFieldHint() {
    return 'Search';
  }

  // Loading States
  static String loadingLabel(String content) {
    return 'Loading $content';
  }

  static String refreshingLabel() {
    return 'Refreshing content';
  }

  // Error States
  static String errorLabel(String message) {
    return 'Error: $message';
  }

  // Helper: Format time ago for accessibility
  static String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return 'over a week ago';
    }
  }
}

/// Extension to easily wrap widgets with semantic labels
extension AccessibleWidget on Widget {
  /// Wrap widget with semantic label for images
  Widget asAccessibleImage(String label, {String? hint}) {
    return Semantics(
      label: label,
      image: true,
      hint: hint,
      child: this,
    );
  }

  /// Wrap widget with semantic label for buttons
  Widget asAccessibleButton(String label, {String? hint}) {
    return Semantics(
      label: label,
      button: true,
      hint: hint ?? 'Double tap to activate',
      child: this,
    );
  }

  /// Wrap widget with semantic label for links
  Widget asAccessibleLink(String label) {
    return Semantics(
      label: label,
      link: true,
      hint: 'Double tap to open',
      child: this,
    );
  }

  /// Exclude widget from semantic tree (for decorative elements)
  Widget excludeFromSemantics() {
    return ExcludeSemantics(child: this);
  }

  /// Merge child semantics into one
  Widget mergeSemantics() {
    return MergeSemantics(child: this);
  }
}
