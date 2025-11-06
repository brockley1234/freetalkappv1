import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_theme.dart';

/// Skeleton loading placeholder with shimmer effect
/// Improves perceived performance by showing content structure while loading
class SkeletonLoader extends StatelessWidget {
  final double height;
  final double width;
  final BorderRadius borderRadius;
  final EdgeInsets margin;

  const SkeletonLoader({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppBorderRadius.md),
    ),
    this.margin = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor:
          isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
      highlightColor: isDark ? AppColors.darkSurfaceDim : AppColors.surfaceDim,
      child: Container(
        margin: margin,
        height: height,
        width: width,
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}

/// Circle skeleton for avatars
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsets margin;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.margin = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      height: size,
      width: size,
      borderRadius: BorderRadius.circular(AppBorderRadius.full),
      margin: margin,
    );
  }
}

/// Post card skeleton loading placeholder
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (avatar + name + time)
          Row(
            children: [
              SkeletonCircle(size: 48),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      height: 14,
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: AppSpacing.sm),
                    ),
                    SkeletonLoader(
                      height: 10,
                      width: 100,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          // Content lines
          SkeletonLoader(
            height: 14,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          SkeletonLoader(
            height: 14,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          SkeletonLoader(
            height: 14,
            width: 200,
          ),
          SizedBox(height: AppSpacing.md),

          // Image placeholder
          SkeletonLoader(
            height: 200,
            width: double.infinity,
          ),
          SizedBox(height: AppSpacing.md),

          // Action buttons
          Row(
            children: [
              SkeletonLoader(height: 32, width: 80),
              SizedBox(width: AppSpacing.md),
              SkeletonLoader(height: 32, width: 80),
              SizedBox(width: AppSpacing.md),
              SkeletonLoader(height: 32, width: 80),
            ],
          ),
        ],
      ),
    );
  }
}

/// Message skeleton for chat
class MessageSkeleton extends StatelessWidget {
  final bool isOwnMessage;

  const MessageSkeleton({
    super.key,
    this.isOwnMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isOwnMessage) ...[
            const SkeletonCircle(size: 32),
            const SizedBox(width: AppSpacing.sm),
          ],
          Column(
            crossAxisAlignment: isOwnMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              SkeletonLoader(
                height: 40,
                width: 200,
                borderRadius: BorderRadius.circular(AppBorderRadius.lg),
              ),
              const SizedBox(height: 4),
              const SkeletonLoader(
                height: 10,
                width: 60,
              ),
            ],
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: AppSpacing.sm),
            const SkeletonCircle(size: 32),
          ],
        ],
      ),
    );
  }
}

/// User list item skeleton
class UserListSkeleton extends StatelessWidget {
  const UserListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SkeletonCircle(size: 48),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  height: 14,
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 6),
                ),
                SkeletonLoader(
                  height: 12,
                  width: 150,
                ),
              ],
            ),
          ),
          SkeletonLoader(
            height: 36,
            width: 80,
          ),
        ],
      ),
    );
  }
}

/// Notification skeleton
class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          SkeletonCircle(size: 40),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(
                  height: 14,
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 6),
                ),
                SkeletonLoader(
                  height: 12,
                  width: 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Story circle skeleton
class StorySkeleton extends StatelessWidget {
  const StorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          SkeletonCircle(size: 64),
          SizedBox(height: AppSpacing.sm),
          SkeletonLoader(
            height: 10,
            width: 60,
          ),
        ],
      ),
    );
  }
}

/// Generic list skeleton
class ListSkeleton extends StatelessWidget {
  final int itemCount;
  final Widget Function() itemBuilder;

  const ListSkeleton({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(),
    );
  }
}

/// Profile header skeleton
class ProfileHeaderSkeleton extends StatelessWidget {
  const ProfileHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Cover photo
        const SkeletonLoader(
          height: 200,
          width: double.infinity,
          borderRadius: BorderRadius.zero,
        ),
        Transform.translate(
          offset: const Offset(0, -40),
          child: const Column(
            children: [
              // Avatar
              SkeletonCircle(size: 120),
              SizedBox(height: AppSpacing.md),
              // Name
              SkeletonLoader(height: 20, width: 150),
              SizedBox(height: AppSpacing.sm),
              // Bio
              SkeletonLoader(height: 14, width: 250),
              SizedBox(height: AppSpacing.md),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonLoader(height: 40, width: 80),
                  SizedBox(width: AppSpacing.lg),
                  SkeletonLoader(height: 40, width: 80),
                  SizedBox(width: AppSpacing.lg),
                  SkeletonLoader(height: 40, width: 80),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
