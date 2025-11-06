import 'package:intl/intl.dart';

/// Utility class for formatting timestamps in a Messenger-like style
/// All timestamps are treated as UTC and converted to local time for display
class TimeUtils {
  /// Parse a timestamp string and convert to local time
  /// MongoDB timestamps come as UTC ISO strings, DateTime.parse handles them correctly
  static DateTime parseToLocal(String? timestamp) {
    if (timestamp == null) return DateTime.now();

    try {
      // DateTime.parse() automatically handles UTC timestamps correctly
      // If the string has 'Z' suffix, it's parsed as UTC and toLocal() converts it
      // If no 'Z', it's treated as local time already
      DateTime parsedTime = DateTime.parse(timestamp);

      // If the parsed time is already in UTC, convert to local
      // MongoDB sends timestamps with 'Z' suffix, so they'll be UTC
      if (parsedTime.isUtc) {
        return parsedTime.toLocal();
      }

      // If it's already local or unspecified, return as-is
      return parsedTime;
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Format time ago in Messenger style (e.g., "5m", "2h", "3d")
  static String formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'just now';

    try {
      final localTime = parseToLocal(timestamp);
      final now = DateTime.now();
      final difference = now.difference(localTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks}w';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '${months}mo';
      } else {
        final years = (difference.inDays / 365).floor();
        return '${years}y';
      }
    } catch (e) {
      return 'just now';
    }
  }

  /// Format time ago from a DateTime object (e.g., "5m", "2h", "3d")
  /// Used when you already have a DateTime object instead of a string timestamp
  static String getTimeAgo(DateTime dateTime) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '${weeks}w';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '${months}mo';
      } else {
        final years = (difference.inDays / 365).floor();
        return '${years}y';
      }
    } catch (e) {
      return 'just now';
    }
  }

  /// Format full timestamp for message details (e.g., "Today at 2:30 PM")
  static String formatFullTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final localTime = parseToLocal(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate =
          DateTime(localTime.year, localTime.month, localTime.day);

      final timeFormat = DateFormat('h:mm a'); // e.g., "2:30 PM"
      final dateFormat = DateFormat('MMM d, y'); // e.g., "Jan 15, 2025"
      final dayFormat = DateFormat('EEEE'); // Full day name

      // Today: show "Today at 2:30 PM"
      if (messageDate == today) {
        return 'Today at ${timeFormat.format(localTime)}';
      }
      // Yesterday: show "Yesterday at 2:30 PM"
      else if (messageDate == yesterday) {
        return 'Yesterday at ${timeFormat.format(localTime)}';
      }
      // Within a week: show day name and time, e.g., "Monday at 2:30 PM"
      else if (now.difference(localTime).inDays < 7) {
        return '${dayFormat.format(localTime)} at ${timeFormat.format(localTime)}';
      }
      // Older: show full date and time, e.g., "Jan 15, 2025 at 2:30 PM"
      else {
        return '${dateFormat.format(localTime)} at ${timeFormat.format(localTime)}';
      }
    } catch (e) {
      return '';
    }
  }

  /// Format date separator for message groups (e.g., "Today", "Yesterday", "Monday")
  static String formatDateSeparator(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final localTime = parseToLocal(timestamp);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final messageDate =
          DateTime(localTime.year, localTime.month, localTime.day);

      if (messageDate == today) {
        return 'Today';
      } else if (messageDate == yesterday) {
        return 'Yesterday';
      } else if (now.difference(localTime).inDays < 7) {
        return DateFormat('EEEE').format(localTime); // Day name
      } else {
        return DateFormat('MMM d, yyyy').format(localTime);
      }
    } catch (e) {
      return '';
    }
  }

  /// Format last active time (e.g., "Active 5m ago", "Active now")
  static String formatLastActive(String? timestamp) {
    if (timestamp == null) return 'Last seen recently';

    try {
      final localTime = parseToLocal(timestamp);
      final now = DateTime.now();
      final difference = now.difference(localTime);

      if (difference.inMinutes < 1) {
        return 'Active now';
      } else if (difference.inMinutes < 60) {
        return 'Active ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Active ${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return 'Active ${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'Active ${weeks}w ago';
      } else {
        return 'Last seen recently';
      }
    } catch (e) {
      return 'Last seen recently';
    }
  }

  /// Format message time in short format (e.g., "2:30 PM" for same day messages)
  static String formatMessageTime(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final localTime = parseToLocal(timestamp);
      final timeFormat = DateFormat('h:mm a');
      return timeFormat.format(localTime);
    } catch (e) {
      return '';
    }
  }

  /// Format timestamp as YYYY/MM/DD HH:MM for chat messages
  static String formatMessageTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    try {
      final localTime = parseToLocal(timestamp);
      // Format as YYYY/MM/DD HH:MM (24-hour format)
      final year = localTime.year.toString();
      final month = localTime.month.toString().padLeft(2, '0');
      final day = localTime.day.toString().padLeft(2, '0');
      final hour = localTime.hour.toString().padLeft(2, '0');
      final minute = localTime.minute.toString().padLeft(2, '0');
      return '$year/$month/$day $hour:$minute';
    } catch (e) {
      return '';
    }
  }
}
