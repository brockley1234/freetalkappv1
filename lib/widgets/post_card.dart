import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_player_widget.dart';
import 'mention_text.dart';
import 'post_reactions_viewer.dart';
import '../utils/url_utils.dart';
import '../pages/user_profile_page.dart';

class PostCard extends StatefulWidget {
  final String postId;
  final String authorId;
  final String userName;
  final String? userAvatar;
  final String timeAgo;
  final String content;
  final int reactionsCount;
  final int comments;
  final String? userReaction;
  final Map<String, dynamic> reactionsSummary;
  final List<String>? images;
  final List<String>? videos;
  final VoidCallback onReactionTap;
  final VoidCallback onCommentTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onUserTap;
  final bool isShared;
  final Map<String, dynamic>? sharedBy;
  final String? shareMessage;
  final List<Map<String, dynamic>>? taggedUsers;
  final Map<String, dynamic>? authorData; // For verified badge check
  final bool isTrending; // New: indicates if post is trending
  final int? sharesCount; // New: number of shares
  final List<Map<String, dynamic>>?
      topComments; // New: top 1-2 comments for preview

  const PostCard({
    super.key,
    required this.postId,
    required this.authorId,
    required this.userName,
    required this.userAvatar,
    required this.timeAgo,
    required this.content,
    required this.reactionsCount,
    required this.comments,
    this.userReaction,
    required this.reactionsSummary,
    this.images,
    this.videos,
    required this.onReactionTap,
    required this.onCommentTap,
    required this.onSettingsTap,
    this.onShareTap,
    this.onUserTap,
    this.isShared = false,
    this.sharedBy,
    this.shareMessage,
    this.taggedUsers,
    this.authorData,
    this.isTrending = false,
    this.sharesCount,
    this.topComments,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with TickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _hoverElevation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Hover animation for web/desktop interaction
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _hoverElevation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  // Build a map of mention names to user IDs for quick lookup
  Map<String, String> _buildMentionIdMap() {
    final mentionMap = <String, String>{};
    if (widget.taggedUsers != null) {
      for (final user in widget.taggedUsers!) {
        final name = user['name'] as String?;
        final id = user['_id'] as String?;
        if (name != null && id != null) {
          mentionMap[name] = id;
        }
      }
    }
    return mentionMap;
  }

  /// Build avatar widget - handles both network and local asset avatars (for bots)
  /// IMPROVED: Proper handling for bot avatars from API endpoints
  Widget _buildAvatarWidget() {
    final isBot = widget.authorData?['isBot'] == true;
    final avatarUrl = widget.userAvatar;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      // Fallback: Generate initials
      final theme = Theme.of(context);
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          widget.userName.isNotEmpty
              ? widget.userName
                  .split(' ')
                  .map((n) => n[0])
                  .take(2)
                  .join()
                  .toUpperCase()
              : 'U',
          style: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    // Check if it's a local asset (e.g., 'assets/bot_avatars/...' or '/assets/...')
    if (UrlUtils.isLocalAsset(avatarUrl)) {
      // Local asset - use Image widget with AssetImage
      final assetPath =
          avatarUrl.startsWith('/') ? avatarUrl.substring(1) : avatarUrl;
      final theme = Theme.of(context);
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: ClipOval(
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('⚠️ Failed to load local asset: $assetPath');
              return Text(
                widget.userName.isNotEmpty
                    ? widget.userName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join()
                        .toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              );
            },
          ),
        ),
      );
    }

    // Check if it's a bot avatar API endpoint (e.g., '/api/user/bot-avatar/ai_assistant')
    if (isBot && UrlUtils.isBotAvatarEndpoint(avatarUrl)) {
      // Bot avatar API endpoint - use CachedNetworkImage for better SVG support
      final theme = Theme.of(context);
      return CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: UrlUtils.getFullAvatarUrl(avatarUrl),
            fit: BoxFit.cover,
            httpHeaders: const {
              'Accept': 'image/svg+xml, image/*',
            },
            placeholder: (context, url) {
              return Container(
                color: theme.colorScheme.primaryContainer,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              );
            },
            errorWidget: (context, url, error) {
              debugPrint('❌ Failed to load bot avatar from: $url');
              debugPrint('   Error: $error');
              return Container(
                color: theme.colorScheme.primaryContainer,
                child: Text(
                  widget.userName.isNotEmpty
                      ? widget.userName
                          .split(' ')
                          .map((n) => n[0])
                          .take(2)
                          .join()
                          .toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Regular user network avatar - use CircleAvatar with NetworkImage
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: 24,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: NetworkImage(UrlUtils.getFullAvatarUrl(avatarUrl)),
      child: null,
    );
  }

  bool get _shouldTruncate => widget.content.length > 300;

  // Wraps media content with responsive max-width for desktop
  Widget _wrapMediaResponsive(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive breakpoints
        final screenWidth = constraints.maxWidth;
        double maxWidth;

        if (screenWidth > 1024) {
          // Large desktop - max 600px
          maxWidth = 600.0;
        } else if (screenWidth > 768) {
          // Tablet/medium desktop - 90% of available space, max 500px
          maxWidth = min(screenWidth * 0.9, 500.0);
        } else if (screenWidth > 480) {
          // Small tablet/large phone - full width with padding
          maxWidth = screenWidth - 32; // 16px padding on each side
        } else {
          // Mobile - full width
          maxWidth = screenWidth;
        }

        // Apply max-width constraint
        if (screenWidth > 600) {
          return Center(
            child: SizedBox(
              width: maxWidth,
              child: child,
            ),
          );
        }
        // On mobile, use full width
        return child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _hoverElevation,
          builder: (context, child) {
            return MouseRegion(
              onEnter: (_) {
                _hoverController.forward();
                setState(() => _isHovering = true);
              },
              onExit: (_) {
                _hoverController.reverse();
                setState(() => _isHovering = false);
              },
              child: Card(
                elevation: isDark ? 4 : _hoverElevation.value,
                shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                color: Theme.of(context).colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    gradient: isDark
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isHovering
                                ? [
                                    Theme.of(context).colorScheme.surface,
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ]
                                : [
                                    Theme.of(context).colorScheme.surface,
                                    Theme.of(context).colorScheme.surfaceContainerHighest,
                                  ],
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trending badge
                        if (widget.isTrending) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.tertiary,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '🔥 Trending',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Share attribution banner
                        if (widget.isShared && widget.sharedBy != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.repeat,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${widget.sharedBy!['name']} shared this post',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (widget.shareMessage != null &&
                                          widget.shareMessage!.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            widget.shareMessage!,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                                              fontSize: 12,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Header
                        Row(
                          children: [
                            GestureDetector(
                              onTap: widget.onUserTap,
                              child: Hero(
                                tag: 'avatar_${widget.authorId}',
                                child: Semantics(
                                  label: '${widget.userName} profile picture',
                                  button: true,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: _buildAvatarWidget(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: widget.onUserTap,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            widget.userName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              letterSpacing: -0.3,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.timeAgo,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                              fontSize: 13,
                                            ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: widget.onSettingsTap,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.more_vert,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Content with clickable @mentions and "Read more"
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 300),
                          crossFadeState: _isExpanded || !_shouldTruncate
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MentionText(
                                text: widget.content.length > 300
                                    ? '${widget.content.substring(0, 300)}...'
                                    : widget.content,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                                mentionStyle: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                onMentionTapWithId: (userName, userId) {
                                  // Navigate to user profile when mentioned user is tapped
                                  if (widget.taggedUsers != null) {
                                    final user = widget.taggedUsers!.firstWhere(
                                      (u) => u['_id'] == userId,
                                      orElse: () => {},
                                    );
                                    if (user.isNotEmpty &&
                                        user['_id'] != null) {
                                      debugPrint(
                                        'Navigating to user profile: $userName ($userId)',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfilePage(
                                            userId: userId,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                mentionIdMap: _buildMentionIdMap(),
                              ),
                              if (_shouldTruncate)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _isExpanded = true),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Read more →',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MentionText(
                                text: widget.content,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                                mentionStyle: TextStyle(
                                  fontSize: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                onMentionTapWithId: (userName, userId) {
                                  // Navigate to user profile when mentioned user is tapped
                                  if (widget.taggedUsers != null) {
                                    final user = widget.taggedUsers!.firstWhere(
                                      (u) => u['_id'] == userId,
                                      orElse: () => {},
                                    );
                                    if (user.isNotEmpty &&
                                        user['_id'] != null) {
                                      debugPrint(
                                        'Navigating to user profile: $userName ($userId)',
                                      );
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfilePage(
                                            userId: userId,
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                mentionIdMap: _buildMentionIdMap(),
                              ),
                              if (_shouldTruncate && _isExpanded)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => _isExpanded = false),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Show less ↑',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Tagged users
                        if (widget.taggedUsers != null &&
                            widget.taggedUsers!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'with ',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                                ...widget.taggedUsers!
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                  final index = entry.key;
                                  final user = entry.value;
                                  final isLast =
                                      index == widget.taggedUsers!.length - 1;

                                  return Semantics(
                                    button: true,
                                    label: 'View ${user['name']} profile',
                                    child: GestureDetector(
                                      onTap: widget.onUserTap,
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: Text(
                                          '${user['name']}${isLast ? '' : ', '}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            decoration:
                                                TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],

                        // Images
                        if (widget.images != null &&
                            widget.images!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _wrapMediaResponsive(_buildImageGrid(widget.images!)),
                        ],

                        // Videos
                        if (widget.videos != null &&
                            widget.videos!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          ...widget.videos!.map(
                            (videoUrl) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _wrapMediaResponsive(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 500,
                                    minHeight: 200,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: VideoPlayerWidget(
                                        videoUrl:
                                            UrlUtils.getFullVideoUrl(videoUrl)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Comment preview (showing top 1-2 comments)
                        if (widget.topComments != null &&
                            widget.topComments!.isNotEmpty) ...[
                          _buildCommentPreview(),
                          const SizedBox(height: 12),
                        ],

                        // Reactions summary
                        if (widget.reactionsSummary.isNotEmpty) ...[
                          _buildReactionsSummary(),
                          const SizedBox(height: 14),
                        ],

                        // Engagement stats
                        _buildEngagementStats(),

                        Divider(
                          color: Theme.of(context).dividerColor,
                          height: 20,
                          thickness: 1,
                        ),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildActionButton(
                              icon: Icons.thumb_up_outlined,
                              selectedIcon: Icons.thumb_up,
                              label: 'React',
                              count: widget.reactionsCount,
                              isSelected: widget.userReaction != null,
                              onTap: widget.onReactionTap,
                            ),
                            _buildActionButton(
                              icon: Icons.comment_outlined,
                              selectedIcon: Icons.comment,
                              label: 'Comment',
                              count: widget.comments,
                              isSelected: false,
                              onTap: widget.onCommentTap,
                            ),
                            _buildActionButton(
                              icon: Icons.share_outlined,
                              selectedIcon: Icons.share,
                              label: 'Share',
                              isSelected: false,
                              onTap: widget.onShareTap ?? () {},
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    if (images.length == 1) {
      return Builder(
        builder: (BuildContext ctx) => Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _openImageFullscreen(ctx, images, 0);
            },
            child: Semantics(
              label: 'Photo posted by ${widget.userName}',
              image: true,
              button: true,
              hint: 'Double tap to view full screen',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 200,
                    maxHeight: 400,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: UrlUtils.getFullImageUrl(images[0]),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) {
                        debugPrint('🖼️ Loading image: $url');
                        return Container(
                          height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Container(
                          height: 300,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  error.toString(),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 100),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: images.length == 2 ? 2 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length > 4 ? 4 : images.length,
      itemBuilder: (context, index) {
        final isLast = index == 3 && images.length > 4;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              _openImageFullscreen(context, images, index);
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: UrlUtils.getFullImageUrl(images[index]),
                      fit: BoxFit.cover,
                      placeholder: (context, url) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                              ],
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      },
                      errorWidget: (context, url, error) {
                        return Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Error',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 10,
                                  ),
                              ),
                            ],
                          ),
                        );
                      },
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 100),
                    ),
                    if (isLast)
                      Container(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.7),
                        child: Center(
                          child: Text(
                            '+${images.length - 4}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openImageFullscreen(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    debugPrint(
      '🚀 Opening fullscreen viewer with ${images.length} images, starting at index $initialIndex',
    );
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImageFullscreenViewer(images: images, initialIndex: initialIndex),
        ),
      );
    } catch (e) {
      // Navigation error
    }
  }

  Widget _buildEngagementStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatBadge(
            icon: Icons.thumb_up_outlined,
            label: '${widget.reactionsCount}',
            color: Theme.of(context).colorScheme.primary,
          ),
          _buildStatBadge(
            icon: Icons.comment_outlined,
            label: '${widget.comments}',
            color: Theme.of(context).colorScheme.secondary,
          ),
          if (widget.sharesCount != null)
            _buildStatBadge(
              icon: Icons.share_outlined,
              label: '${widget.sharesCount}',
              color: Theme.of(context).colorScheme.tertiary,
            ),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentPreview() {
    final comments = widget.topComments ?? [];
    if (comments.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show "Comments" header
          Text(
            'Top ${comments.length} comment${comments.length > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          // Display each comment preview
          ...comments.asMap().entries.map((entry) {
            final comment = entry.value;
            final user = comment['user'] ?? {};
            final userName = user['name'] ?? 'Anonymous';
            final content = comment['content'] ?? '';

            return Padding(
              padding: EdgeInsets.only(top: entry.key > 0 ? 8 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          content,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          // Prompt to view more
          if (widget.comments > comments.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                onTap: widget.onCommentTap,
                child: Text(
                  'View all ${widget.comments} comments →',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionsSummary() {
    final reactionEmojis = {
      'like': '👍',
      'celebrate': '🎉',
      'insightful': '💡',
      'funny': '😄',
      'mindblown': '🤯',
      'support': '❤️',
    };

    final displayedReactions = widget.reactionsSummary.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    if (displayedReactions.isEmpty) return const SizedBox.shrink();

    return InkWell(
      onTap: () {
        // Show reactions viewer
        _showReactionsViewer();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: displayedReactions.take(3).map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Transform.scale(
                    scale: 1.05,
                    child: Text(
                      reactionEmojis[entry.key] ?? '👍',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            Text(
              widget.reactionsCount.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReactionsViewer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Import the PostReactionsViewer widget
        return PostReactionsViewer(
          postId: widget.postId,
          reactionsSummary: widget.reactionsSummary,
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Build semantic label with count information
    String semanticLabel = label;
    if (count != null && count > 0) {
      semanticLabel = '$label, $count ${label.toLowerCase()}s';
    }
    if (isSelected) {
      semanticLabel = '$semanticLabel, selected';
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      hint: 'Double tap to $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Haptic feedback
            HapticFeedback.lightImpact();
            onTap();
          },
          onTapDown: (_) => _animationController.forward(),
          onTapUp: (_) => _animationController.reverse(),
          onTapCancel: () => _animationController.reverse(),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 1.0, end: isSelected ? 1.2 : 1.0),
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: Icon(
                        isSelected ? selectedIcon : icon,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        size: 22,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  count != null && count > 0 ? '$count' : '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (count != null && count > 0) const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fullscreen image viewer
class ImageFullscreenViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const ImageFullscreenViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageFullscreenViewer> createState() => _ImageFullscreenViewerState();
}

class _ImageFullscreenViewerState extends State<ImageFullscreenViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousImage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousImage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextImage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Keep black for image viewer - standard UX
        body: Stack(
          children: [
            // Image viewer with swipe
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _ZoomableImage(imageUrl: widget.images[index]);
              },
            ),

            // Top bar with close button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Counter
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.54), // Semi-transparent overlay for readability
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.images.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface, // Text on overlay for contrast
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Close button
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onSurface, // Icon on overlay for contrast
                        size: 28,
                      ),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.54), // Semi-transparent overlay
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Page indicators (dots) at bottom
            if (widget.images.length > 1)
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.images.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentIndex
                            ? Colors.white // White dots for visibility on dark background
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),

            // Navigation arrows for desktop
            if (widget.images.length > 1) ...[
              // Left arrow
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: Theme.of(context).colorScheme.onSurface, // Icon on overlay
                          size: 32,
                        ),
                        onPressed: _previousImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.54), // Semi-transparent overlay
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                ),
              // Right arrow
              if (_currentIndex < widget.images.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_forward_ios,
                          color: Theme.of(context).colorScheme.onSurface, // Icon on overlay
                          size: 32,
                        ),
                        onPressed: _nextImage,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.54), // Semi-transparent overlay
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// Zoomable image widget with gesture control
class _ZoomableImage extends StatefulWidget {
  final String imageUrl;

  const _ZoomableImage({required this.imageUrl});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final TransformationController _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_controller.value != Matrix4.identity()) {
      // If zoomed in, zoom out
      _controller.value = Matrix4.identity();
    } else {
      // If zoomed out, zoom in to 2x at tap position
      final position = _doubleTapDetails!.localPosition;
      _controller.value = Matrix4.identity()
        ..translateByDouble(-position.dx, -position.dy, 0.0, 1.0)
        ..scaleByDouble(2.0, 2.0, 1.0, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: UrlUtils.getFullImageUrl(widget.imageUrl),
            fit: BoxFit.contain,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onSurface), // Spinner on background
            ),
            errorWidget: (context, url, error) => Center(
              child: Icon(Icons.error, color: Theme.of(context).colorScheme.onSurface, size: 50), // Error icon on background
            ),
          ),
        ),
      ),
    );
  }
}
