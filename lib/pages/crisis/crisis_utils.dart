import 'package:flutter/material.dart';
import '../../utils/app_logger.dart';

/// Utility constants and helpers for crisis pages
class CrisisConstants {
  // Severity levels
  static const List<String> severityLevels = [
    'low',
    'medium',
    'high',
    'critical'
  ];

  // Crisis types
  static const List<MapEntry<String, String>> crisisTypes = [
    MapEntry('mental_health', 'Mental Health'),
    MapEntry('medical_emergency', 'Medical Emergency'),
    MapEntry('safety_threat', 'Safety Threat'),
    MapEntry('domestic_violence', 'Domestic Violence'),
    MapEntry('substance_abuse', 'Substance Abuse'),
    MapEntry('suicide_prevention', 'Suicide Prevention'),
    MapEntry('other', 'Other'),
  ];

  // Visibility options
  static const List<MapEntry<String, String>> visibilityOptions = [
    MapEntry('friends', 'Friends Only'),
    MapEntry('community', 'Entire Community'),
    MapEntry('emergency_contacts', 'Emergency Contacts Only'),
    MapEntry('private', 'Private (Admin Only)'),
  ];

  // Status options
  static const List<String> statusOptions = [
    'active',
    'in_progress',
    'resolved',
    'closed'
  ];

  // Helper status options
  static const List<String> helperStatusOptions = [
    'accepted',
    'helping',
    'completed'
  ];
}

/// Color utilities for crisis severity and status
class CrisisColorUtils {
  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'medium':
        return Colors.yellow.shade700;
      case 'low':
      default:
        return Colors.blue.shade700;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  static Color getHelperStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'helping':
        return Colors.green;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  static Color getVisibilityColor(String visibility) {
    switch (visibility.toLowerCase()) {
      case 'friends':
        return Colors.purple;
      case 'community':
        return Colors.blue;
      case 'emergency_contacts':
        return Colors.orange;
      case 'private':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Icon utilities for crisis features
class CrisisIconUtils {
  static IconData getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      case 'low':
      default:
        return Icons.info_outline;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.emergency;
      case 'in_progress':
        return Icons.hourglass_bottom;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.archive;
      default:
        return Icons.help_outline;
    }
  }

  static IconData getCrisisTypeIcon(String crisisType) {
    switch (crisisType.toLowerCase()) {
      case 'mental_health':
        return Icons.psychology;
      case 'medical_emergency':
        return Icons.local_hospital;
      case 'safety_threat':
        return Icons.security;
      case 'domestic_violence':
        return Icons.pan_tool;
      case 'substance_abuse':
        return Icons.health_and_safety;
      case 'suicide_prevention':
        return Icons.favorite;
      default:
        return Icons.warning_amber_rounded;
    }
  }
}

/// Time formatting utilities
class CrisisTimeUtils {
  static String getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return 'On ${dateTime.month}/${dateTime.day}';
    }
  }

  static String getRelativeDuration(DateTime startTime) {
    final now = DateTime.now();
    final difference = now.difference(startTime);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    }
  }
}

/// Analytics and logging helpers
class CrisisAnalytics {
  static void logCrisisViewed(String crisisId) {
    AppLogger().info('Crisis viewed: $crisisId');
  }

  static void logHelpOffered(String crisisId) {
    AppLogger().info('Help offered for crisis: $crisisId');
  }

  static void logSafetyCheckPerformed(String crisisId) {
    AppLogger().info('Safety check performed on crisis: $crisisId');
  }

  static void logCrisisCreated(String crisisType, String severity) {
    AppLogger().info('Crisis created - Type: $crisisType, Severity: $severity');
  }

  static void logCrisisResolved(String crisisId) {
    AppLogger().info('Crisis resolved: $crisisId');
  }
}

/// Validation utilities
class CrisisValidation {
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please describe your situation';
    }
    if (value.trim().length < 10) {
      return 'Please provide more details (at least 10 characters)';
    }
    if (value.trim().length > 1000) {
      return 'Description is too long (max 1000 characters)';
    }
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final phoneRegex =
        RegExp(r'^[+]?[(]?[0-9]{3}[)]?[-\s.]?[0-9]{3}[-\s.]?[0-9]{4,6}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  static String? validateUpdateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an update message';
    }
    if (value.trim().length < 3) {
      return 'Message is too short (at least 3 characters)';
    }
    if (value.trim().length > 500) {
      return 'Message is too long (max 500 characters)';
    }
    return null;
  }

  static String? validateResourceName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Resource name is required';
    }
    if (value.trim().length < 3) {
      return 'Resource name is too short';
    }
    return null;
  }
}

/// String formatting utilities
class CrisisFormatting {
  static String formatCrisisType(String type) {
    return type.replaceAll('_', ' ').split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  static String formatStatus(String status) {
    final words = status.replaceAll('_', ' ').split(' ');
    return words
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String formatVisibility(String visibility) {
    return visibility.replaceAll('_', ' ').split(' ').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  static String getEmergencyMessage(String severity, String crisisType) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return '🚨 CRITICAL: $crisisType - Immediate assistance needed!';
      case 'high':
        return '⚠️ HIGH PRIORITY: $crisisType - Urgent help required';
      case 'medium':
        return 'ℹ️ MODERATE: $crisisType - Help requested';
      default:
        return '💙 LOW PRIORITY: $crisisType - Assistance available';
    }
  }
}

/// Empty state data models
class EmptyState {
  final String title;
  final String? message;
  final IconData icon;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  EmptyState({
    required this.title,
    this.message,
    required this.icon,
    this.color,
    this.actionLabel,
    this.onAction,
  });

  static EmptyState noCrises() => EmptyState(
        title: 'No Active Crises',
        message: 'Your community is safe',
        icon: Icons.check_circle_outline,
        color: Colors.green.shade300,
      );

  static EmptyState noCrisisHistory() => EmptyState(
        title: 'No Crisis History',
        message: 'You haven\'t requested help yet',
        icon: Icons.info_outline,
        color: Colors.grey.shade400,
      );

  static EmptyState noHelpers() => EmptyState(
        title: 'No Helpers Yet',
        message: 'Be the first to offer help!',
        icon: Icons.people_outline,
        color: Colors.grey.shade400,
      );

  static EmptyState noUpdates() => EmptyState(
        title: 'No Updates',
        message: 'No updates have been shared yet',
        icon: Icons.update,
        color: Colors.grey.shade400,
      );

  static EmptyState noResources() => EmptyState(
        title: 'No Resources',
        message: 'No resources have been shared yet',
        icon: Icons.help_outline,
        color: Colors.grey.shade400,
      );

  static EmptyState searchEmpty() => EmptyState(
        title: 'No Results Found',
        message: 'Try adjusting your filters',
        icon: Icons.search_off,
        color: Colors.grey.shade400,
      );
}
