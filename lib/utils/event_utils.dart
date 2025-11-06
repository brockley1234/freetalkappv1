import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';

enum EventStatus {
  past,
  ongoing,
  upcoming,
  today,
}

class EventUtils {
  /// Get the status of an event based on current time
  static EventStatus getEventStatus(Event event) {
    final now = DateTime.now();
    final startTime = event.startTime;
    final endTime = event.endTime ?? startTime.add(const Duration(hours: 2));

    // Check if event is today
    if (startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day) {
      if (now.isAfter(endTime)) {
        return EventStatus.past;
      } else if (now.isAfter(startTime)) {
        return EventStatus.ongoing;
      } else {
        return EventStatus.today;
      }
    }

    if (now.isAfter(endTime)) {
      return EventStatus.past;
    } else if (now.isAfter(startTime) && now.isBefore(endTime)) {
      return EventStatus.ongoing;
    } else {
      return EventStatus.upcoming;
    }
  }

  /// Get a color for the event status
  static Color getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.past:
        return Colors.grey;
      case EventStatus.ongoing:
        return Colors.green;
      case EventStatus.today:
        return Colors.orange;
      case EventStatus.upcoming:
        return Colors.blue;
    }
  }

  /// Get a label for the event status
  static String getStatusLabel(EventStatus status) {
    switch (status) {
      case EventStatus.past:
        return 'Past';
      case EventStatus.ongoing:
        return 'Live Now';
      case EventStatus.today:
        return 'Today';
      case EventStatus.upcoming:
        return 'Upcoming';
    }
  }

  /// Format date in a user-friendly way
  static String formatEventDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    // Today
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today at ${_formatTime(dateTime)}';
    }

    // Tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    if (dateTime.year == tomorrow.year &&
        dateTime.month == tomorrow.month &&
        dateTime.day == tomorrow.day) {
      return 'Tomorrow at ${_formatTime(dateTime)}';
    }

    // Within next week
    if (difference.inDays >= 0 && difference.inDays < 7) {
      return '${DateFormat('EEEE').format(dateTime)} at ${_formatTime(dateTime)}';
    }

    // Same year
    if (dateTime.year == now.year) {
      return '${DateFormat('MMM d').format(dateTime)} at ${_formatTime(dateTime)}';
    }

    // Different year
    return '${DateFormat('MMM d, yyyy').format(dateTime)} at ${_formatTime(dateTime)}';
  }

  /// Format date range
  static String formatDateRange(DateTime start, DateTime? end) {
    if (end == null) {
      return formatEventDate(start);
    }

    final startDate = DateFormat('MMM d').format(start);
    final endDate = DateFormat('MMM d').format(end);
    final startTime = _formatTime(start);
    final endTime = _formatTime(end);

    // Same day
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '$startDate, $startTime - $endTime';
    }

    // Different days
    return '$startDate, $startTime - $endDate, $endTime';
  }

  /// Format time in 12-hour format
  static String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Get relative time description
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      final absDiff = difference.abs();
      if (absDiff.inDays > 0) {
        return '${absDiff.inDays}d ago';
      } else if (absDiff.inHours > 0) {
        return '${absDiff.inHours}h ago';
      } else if (absDiff.inMinutes > 0) {
        return '${absDiff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } else {
      if (difference.inDays > 0) {
        return 'in ${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return 'in ${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return 'in ${difference.inMinutes}m';
      } else {
        return 'Starting soon';
      }
    }
  }

  /// Check if event is at capacity
  static bool isAtCapacity(Event event) {
    if (event.capacity == null) return false;
    final goingCount = event.rsvps.where((r) => r.status == 'going').length;
    return goingCount >= event.capacity!;
  }

  /// Get attendance percentage
  static double getAttendancePercentage(Event event) {
    if (event.capacity == null) return 0;
    final goingCount = event.rsvps.where((r) => r.status == 'going').length;
    return (goingCount / event.capacity!) * 100;
  }

  /// Get icon for event tag
  static IconData getTagIcon(String tag) {
    final lowerTag = tag.toLowerCase();
    if (lowerTag.contains('music')) return Icons.music_note;
    if (lowerTag.contains('sport')) return Icons.sports;
    if (lowerTag.contains('food')) return Icons.restaurant;
    if (lowerTag.contains('tech')) return Icons.computer;
    if (lowerTag.contains('art')) return Icons.palette;
    if (lowerTag.contains('game')) return Icons.sports_esports;
    if (lowerTag.contains('social')) return Icons.people;
    if (lowerTag.contains('education')) return Icons.school;
    if (lowerTag.contains('business')) return Icons.business;
    if (lowerTag.contains('outdoor')) return Icons.park;
    return Icons.local_offer;
  }
}
