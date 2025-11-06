import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Message delivery status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
}

/// Message status indicator with animations
/// Shows clear visual feedback for message delivery state
class MessageStatusIndicator extends StatefulWidget {
  final MessageStatus status;
  final VoidCallback? onRetry;
  final Color? color;
  final double size;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.onRetry,
    this.color,
    this.size = 14,
  });

  @override
  State<MessageStatusIndicator> createState() => _MessageStatusIndicatorState();
}

class _MessageStatusIndicatorState extends State<MessageStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    if (widget.status == MessageStatus.sending) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(MessageStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == MessageStatus.sending &&
        oldWidget.status != MessageStatus.sending) {
      _rotationController.repeat();
    } else if (widget.status != MessageStatus.sending) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.status) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.error:
        return Icons.error_outline;
    }
  }

  Color _getColor(bool isDark) {
    if (widget.color != null) return widget.color!;

    switch (widget.status) {
      case MessageStatus.sending:
        return AppColors.textTertiary;
      case MessageStatus.sent:
        return isDark
            ? AppColors.textInverse.withValues(alpha: 0.7)
            : AppColors.textSecondary;
      case MessageStatus.delivered:
        return AppColors.info;
      case MessageStatus.read:
        return isDark ? AppColors.primaryLight : AppColors.primary;
      case MessageStatus.error:
        return AppColors.error;
    }
  }

  String _getLabel() {
    switch (widget.status) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.read:
        return 'Read';
      case MessageStatus.error:
        return 'Failed - tap to retry';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getColor(isDark);

    Widget icon;

    if (widget.status == MessageStatus.sending) {
      icon = RotationTransition(
        turns: _rotationController,
        child: Icon(
          _getIcon(),
          size: widget.size,
          color: iconColor,
        ),
      );
    } else {
      icon = Icon(
        _getIcon(),
        size: widget.size,
        color: iconColor,
      );
    }

    // Add fade-in animation for state changes
    icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: icon,
    );

    // Wrap with tap handler for error state
    if (widget.status == MessageStatus.error && widget.onRetry != null) {
      return Semantics(
        button: true,
        label: _getLabel(),
        child: InkWell(
          onTap: widget.onRetry,
          borderRadius: BorderRadius.circular(AppBorderRadius.full),
          child: Tooltip(
            message: _getLabel(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: icon,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: _getLabel(),
      child: Semantics(
        label: _getLabel(),
        child: icon,
      ),
    );
  }
}

/// Combined time and status indicator for messages
class MessageTimeAndStatus extends StatelessWidget {
  final String time;
  final MessageStatus status;
  final VoidCallback? onRetry;
  final bool isOwnMessage;

  const MessageTimeAndStatus({
    super.key,
    required this.time,
    required this.status,
    this.onRetry,
    required this.isOwnMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 11,
            color: isOwnMessage
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.8))
                : AppColors.textTertiary,
          ),
        ),
        if (isOwnMessage) ...[
          const SizedBox(width: 4),
          MessageStatusIndicator(
            status: status,
            onRetry: onRetry,
            size: 14,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.8),
          ),
        ],
      ],
    );
  }
}

/// Compact status badge for message list previews
class CompactMessageStatus extends StatelessWidget {
  final MessageStatus status;
  final double size;

  const CompactMessageStatus({
    super.key,
    required this.status,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.error) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.error,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.priority_high,
          size: size * 0.7,
          color: Colors.white,
        ),
      );
    }

    if (status == MessageStatus.sending) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            AppColors.textTertiary,
          ),
        ),
      );
    }

    return MessageStatusIndicator(
      status: status,
      size: size,
    );
  }
}
