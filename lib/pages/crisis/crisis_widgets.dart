import 'package:flutter/material.dart';
import '../../services/crisis_service.dart';
import 'crisis_utils.dart';

/// Enhanced severity badge widget
class EnhancedSeverityBadge extends StatelessWidget {
  final String severity;
  final bool isCompact;

  const EnhancedSeverityBadge({
    super.key,
    required this.severity,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = CrisisColorUtils.getSeverityColor(severity);
    final icon = CrisisIconUtils.getSeverityIcon(severity);

    if (isCompact) {
      return Tooltip(
        message: CrisisFormatting.formatStatus(severity),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            severity.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced status indicator widget
class EnhancedStatusIndicator extends StatelessWidget {
  final String status;
  final bool showIcon;
  final bool isCompact;

  const EnhancedStatusIndicator({
    super.key,
    required this.status,
    this.showIcon = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = CrisisColorUtils.getStatusColor(status);
    final icon = CrisisIconUtils.getStatusIcon(status);
    final formattedStatus = CrisisFormatting.formatStatus(status);

    if (isCompact) {
      return Tooltip(
        message: formattedStatus,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            formattedStatus,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced crisis type badge
class EnhancedCrisisTypeBadge extends StatelessWidget {
  final String crisisType;
  final bool showIcon;

  const EnhancedCrisisTypeBadge({
    super.key,
    required this.crisisType,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final icon = CrisisIconUtils.getCrisisTypeIcon(crisisType);
    final formatted = CrisisFormatting.formatCrisisType(crisisType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: Colors.purple.shade700),
            const SizedBox(width: 6),
          ],
          Text(
            formatted,
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced empty state widget
class EnhancedEmptyState extends StatelessWidget {
  final EmptyState emptyState;
  final VoidCallback? onRetry;

  const EnhancedEmptyState({
    super.key,
    required this.emptyState,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: 0.8 + (value * 0.2),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (emptyState.color ?? Colors.grey.shade400)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyState.icon,
                size: 80,
                color: emptyState.color ?? Colors.grey.shade400,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            emptyState.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (emptyState.message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                emptyState.message!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (emptyState.onAction != null &&
              emptyState.actionLabel != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: emptyState.onAction,
              icon: const Icon(Icons.add),
              label: Text(emptyState.actionLabel!),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loading widget for crisis cards
class CrisisCardSkeleton extends StatefulWidget {
  const CrisisCardSkeleton({super.key});

  @override
  State<CrisisCardSkeleton> createState() => _CrisisCardSkeletonState();
}

class _CrisisCardSkeletonState extends State<CrisisCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildSkeletonBox(60, 24),
                const SizedBox(width: 8),
                _buildSkeletonBox(80, 24),
                const Spacer(),
                _buildSkeletonBox(50, 24),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSkeletonBox(40, 40, isCircle: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSkeletonBox(150, 16),
                      const SizedBox(height: 8),
                      _buildSkeletonBox(100, 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSkeletonBox(double.infinity, 60),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonBox(double width, double height,
      {bool isCircle = false}) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 0.8).animate(_controller),
      child: Container(
        width: isCircle ? height : width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: !isCircle ? BorderRadius.circular(8) : null,
        ),
      ),
    );
  }
}

/// Enhanced helper profile card
class EnhancedHelperCard extends StatelessWidget {
  final Helper helper;
  final VoidCallback? onTap;

  const EnhancedHelperCard({
    super.key,
    required this.helper,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = CrisisColorUtils.getHelperStatusColor(helper.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  helper.userProfilePicture != null
                      ? CircleAvatar(
                          backgroundImage:
                              NetworkImage(helper.userProfilePicture!),
                          radius: 24,
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.grey.shade300,
                          radius: 24,
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.grey.shade600,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          helper.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CrisisTimeUtils.getTimeAgo(helper.respondedAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      helper.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Text(
                  helper.message,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enhanced stat item widget
class EnhancedStatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const EnhancedStatItem({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button for crisis pages
class QuickActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool disabled;

  const QuickActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isLoading = false,
    this.disabled = false,
  });

  @override
  State<QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          if (!widget.isLoading && !widget.disabled) {
            widget.onPressed();
          }
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: Tween<double>(begin: 1, end: 0.95).animate(_controller),
          child: ElevatedButton.icon(
            onPressed:
                widget.disabled || widget.isLoading ? null : widget.onPressed,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(widget.icon),
            label: Text(widget.label),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
