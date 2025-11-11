import 'package:flutter/material.dart';
import '../utils/responsive_dimensions.dart';
import '../utils/url_utils.dart';
import '../utils/avatar_utils.dart';

/// Enhanced post card with improved UI, animations, and interactions
class EnhancedPostCard extends StatefulWidget {
  final String postId;
  final String authorId;
  final String userName;
  final String? userAvatar;
  final String timeAgo;
  final String content;
  final int reactionsCount;
  final int commentsCount;
  final String? userReaction;
  final Map<String, dynamic> reactionsSummary;
  final List<String>? images;
  final List<String>? videos;
  final bool isVerified;
  final bool isShared;
  final dynamic sharedBy;
  final String? shareMessage;
  final VoidCallback onCommentTap;
  final VoidCallback onReactionTap;
  final VoidCallback onShareTap;
  final VoidCallback onMoreTap;
  final Function(String)? onReact; // New: for quick reactions

  const EnhancedPostCard({
    super.key,
    required this.postId,
    required this.authorId,
    required this.userName,
    this.userAvatar,
    required this.timeAgo,
    required this.content,
    required this.reactionsCount,
    required this.commentsCount,
    this.userReaction,
    required this.reactionsSummary,
    this.images,
    this.videos,
    this.isVerified = false,
    this.isShared = false,
    this.sharedBy,
    this.shareMessage,
    required this.onCommentTap,
    required this.onReactionTap,
    required this.onShareTap,
    required this.onMoreTap,
    this.onReact,
  }) : super();

  @override
  State<EnhancedPostCard> createState() => _EnhancedPostCardState();
}

class _EnhancedPostCardState extends State<EnhancedPostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _reactionAnimController;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _reactionAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _reactionAnimController.dispose();
    super.dispose();
  }

  void _triggerReactionAnimation() {
    _reactionAnimController.forward().then((_) {
      _reactionAnimController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);
    final borderRadius = ResponsiveDimensions.getBorderRadius(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _isHovering
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with author info and options
            _buildPostHeader(context, padding, spacing),

            // Shared post indicator (if applicable)
            if (widget.isShared) _buildSharedIndicator(context, padding),

            // Content section
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: padding, vertical: spacing),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main content text
                  Text(
                    widget.content,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                  ),

                  // Media section
                  if (widget.images != null || widget.videos != null) ...[
                    SizedBox(height: spacing),
                    _buildMediaPreview(context, borderRadius),
                  ],
                ],
              ),
            ),

            // Engagement metrics section
            _buildEngagementMetrics(context, padding, spacing),

            // Action buttons with hover effects
            _buildActionButtons(context, padding, spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(
      BuildContext context, double padding, double spacing) {
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: [
          // Author avatar
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AvatarWithFallback(
              name: widget.userName,
              imageUrl: widget.userAvatar,
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
              getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
            ),
          ),
          SizedBox(width: spacing),

          // Author info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.userName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    if (widget.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: spacing * 0.25),
                Text(
                  widget.timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),

          // More options button
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: widget.onMoreTap,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'More options',
          ),
        ],
      ),
    );
  }

  Widget _buildSharedIndicator(BuildContext context, double padding) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.all(padding * 0.75),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.share,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          SizedBox(width: padding * 0.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shared by ${widget.sharedBy is Map ? widget.sharedBy['name'] : 'someone'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (widget.shareMessage != null)
                  Text(
                    widget.shareMessage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context, double borderRadius) {
    final mediaCount =
        (widget.images?.length ?? 0) + (widget.videos?.length ?? 0);
    final hasMultipleMedia = mediaCount > 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Show first image/video thumbnail
          if (widget.images != null && widget.images!.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius - 2),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Image.network(
                widget.images!.first,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.expand(
                    child: Icon(Icons.broken_image, size: 32),
                  );
                },
              ),
            ),
          if (widget.videos != null && widget.videos!.isNotEmpty)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius - 2),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Icon(
                  Icons.play_circle_filled,
                  size: 56,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),

          // Media count badge
          if (hasMultipleMedia)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+${mediaCount - 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEngagementMetrics(
      BuildContext context, double padding, double spacing) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Reactions metric
          _buildMetricBubble(
            context,
            icon: Icons.favorite,
            label: widget.reactionsCount > 0
                ? '${widget.reactionsCount} reaction${widget.reactionsCount != 1 ? 's' : ''}'
                : 'React',
            onTap: widget.onReactionTap,
          ),

          // Comments metric
          _buildMetricBubble(
            context,
            icon: Icons.chat_bubble_outline,
            label: widget.commentsCount > 0
                ? '${widget.commentsCount} comment${widget.commentsCount != 1 ? 's' : ''}'
                : 'Comment',
            onTap: widget.onCommentTap,
          ),

          // Shares metric (if available)
          _buildMetricBubble(
            context,
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: widget.onShareTap,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBubble(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, double padding, double spacing) {
    final hasReacted = widget.userReaction != null;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: [
          // Quick reaction button
          Expanded(
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                CurvedAnimation(
                    parent: _reactionAnimController, curve: Curves.elasticOut),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _triggerReactionAnimation();
                    widget.onReact?.call(widget.userReaction ?? 'like');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
                    decoration: BoxDecoration(
                      color: hasReacted
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasReacted
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasReacted ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: hasReacted
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        SizedBox(width: spacing * 0.5),
                        Text(
                          hasReacted ? 'Unlike' : 'Like',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: hasReacted 
                                ? Theme.of(context).colorScheme.error 
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: spacing * 0.75),

          // Comment button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onCommentTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: spacing * 0.75),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: spacing * 0.5),
                      Text(
                        'Comment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
