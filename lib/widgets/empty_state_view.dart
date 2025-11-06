import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../config/app_typography.dart';

/// Empty state view with icon, text, and optional action
/// Guides users when there's no content to display
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final List<String>? suggestions;
  final Widget? customWidget;
  final Color? iconColor;
  final double iconSize;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onActionPressed,
    this.suggestions,
    this.customWidget,
    this.iconColor,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with gradient background
              Container(
                width: iconSize * 1.5,
                height: iconSize * 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                      (iconColor ?? AppColors.accent).withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: iconColor ??
                      (isDark ? AppColors.primaryLight : AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                title,
                style: AppTypography.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Description
              Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textInverse.withValues(alpha: 0.7)
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Custom widget (if provided)
              if (customWidget != null) ...[
                customWidget!,
                const SizedBox(height: AppSpacing.xl),
              ],

              // Suggestions (if provided)
              if (suggestions != null && suggestions!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppBorderRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick tips:',
                        style: AppTypography.labelLarge.copyWith(
                          color: isDark
                              ? AppColors.textInverse
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ...suggestions!.map((tip) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.primaryLight
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: isDark
                                          ? AppColors.textInverse
                                              .withValues(alpha: 0.8)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // Action button
              if (actionLabel != null && onActionPressed != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onActionPressed,
                    child: Text(actionLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Predefined empty states for common scenarios
class EmptyStates {
  /// No posts in feed
  static Widget noPosts({
    required BuildContext context,
    VoidCallback? onExplore,
  }) {
    return EmptyStateView(
      icon: Icons.feed_outlined,
      title: 'Nothing to show yet',
      description: 'Follow friends to see their posts in your feed',
      actionLabel: 'Explore Users',
      onActionPressed: onExplore,
      suggestions: const [
        'Follow at least 5 friends to start',
        'Check trending posts for inspiration',
        'Create your first post to break the ice',
      ],
    );
  }

  /// No messages
  static Widget noMessages({
    required BuildContext context,
    VoidCallback? onFindFriends,
  }) {
    return EmptyStateView(
      icon: Icons.mail_outline,
      title: 'No messages yet',
      description: 'Start a conversation with your friends!',
      actionLabel: 'Find Friends',
      onActionPressed: onFindFriends,
      suggestions: const [
        'Connect with people who share your interests',
        'Join clubs to meet like-minded users',
        'Send pokes to start conversations',
      ],
    );
  }

  /// No notifications
  static Widget noNotifications({
    required BuildContext context,
  }) {
    return const EmptyStateView(
      icon: Icons.notifications_none_outlined,
      title: 'No notifications',
      description: 'You\'re all caught up! Check back later for updates.',
      iconColor: AppColors.info,
    );
  }

  /// No search results
  static Widget noSearchResults({
    required BuildContext context,
    String? query,
  }) {
    return EmptyStateView(
      icon: Icons.search_off,
      title: 'No results found',
      description: query != null
          ? 'No results for "$query". Try different keywords.'
          : 'Try searching for users, posts, or hashtags',
      suggestions: const [
        'Check your spelling',
        'Try more general keywords',
        'Use hashtags to find trending content',
      ],
    );
  }

  /// No saved posts
  static Widget noSavedPosts({
    required BuildContext context,
  }) {
    return const EmptyStateView(
      icon: Icons.bookmark_border,
      title: 'No saved posts',
      description: 'Tap the bookmark icon on posts you want to save for later',
      iconColor: AppColors.warning,
    );
  }

  /// No followers/following
  static Widget noConnections({
    required BuildContext context,
    VoidCallback? onFindPeople,
    bool isFollowers = true,
  }) {
    return EmptyStateView(
      icon: Icons.people_outline,
      title: isFollowers ? 'No followers yet' : 'Not following anyone',
      description: isFollowers
          ? 'People who follow you will appear here'
          : 'Start following people to see their content',
      actionLabel: 'Find People',
      onActionPressed: onFindPeople,
    );
  }

  /// No events
  static Widget noEvents({
    required BuildContext context,
    VoidCallback? onCreate,
  }) {
    return EmptyStateView(
      icon: Icons.event_outlined,
      title: 'No events',
      description: 'Create or discover events in your community',
      actionLabel: 'Create Event',
      onActionPressed: onCreate,
    );
  }

  /// No clubs
  static Widget noClubs({
    required BuildContext context,
    VoidCallback? onExplore,
  }) {
    return EmptyStateView(
      icon: Icons.groups_outlined,
      title: 'No clubs yet',
      description: 'Join clubs to connect with people who share your interests',
      actionLabel: 'Explore Clubs',
      onActionPressed: onExplore,
    );
  }

  /// Network error
  static Widget networkError({
    required BuildContext context,
    VoidCallback? onRetry,
  }) {
    return EmptyStateView(
      icon: Icons.wifi_off_outlined,
      title: 'Connection lost',
      description: 'Please check your internet connection and try again',
      actionLabel: 'Retry',
      onActionPressed: onRetry,
      iconColor: AppColors.error,
    );
  }

  /// Generic error
  static Widget error({
    required BuildContext context,
    String? message,
    VoidCallback? onRetry,
  }) {
    return EmptyStateView(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      description:
          message ?? 'We couldn\'t load this content. Please try again.',
      actionLabel: onRetry != null ? 'Try Again' : null,
      onActionPressed: onRetry,
      iconColor: AppColors.error,
    );
  }
}
