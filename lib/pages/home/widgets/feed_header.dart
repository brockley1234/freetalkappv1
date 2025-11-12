import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/url_utils.dart';
import '../../../utils/responsive_dimensions.dart';

/// Feed header with banner and user info
class FeedHeader extends StatelessWidget {
  final Map<String, dynamic>? currentUser;

  const FeedHeader({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final feedBannerUrl = currentUser?['feedBannerPhoto'];
    final hasPhoto = feedBannerUrl != null && feedBannerUrl.isNotEmpty;

    return FlexibleSpaceBar(
      centerTitle: false,
      titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
      title: Text(
        'ReelTalk',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: ResponsiveDimensions.getHeadingFontSize(context),
          color: hasPhoto ? Colors.white : Theme.of(context).colorScheme.onSurface,
          shadows: hasPhoto
              ? [
                  const Shadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
      ),
      background: hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: UrlUtils.getFullImageUrl(feedBannerUrl),
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.error),
                  ),
                ),
                // Gradient overlay for better text visibility
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
            ),
    );
  }
}

