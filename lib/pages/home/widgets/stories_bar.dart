import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../utils/url_utils.dart';
import '../../story_viewer_page.dart';

/// Horizontal scrolling stories bar
class StoriesBar extends StatelessWidget {
  final List<dynamic> stories;
  final String? currentUserId;

  const StoriesBar({
    super.key,
    required this.stories,
    this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length,
        itemBuilder: (context, index) {
          final story = stories[index];
          final user = story['user'] ?? {};
          final userName = user['name'] ?? 'Unknown';
          final userAvatar = user['avatar'];
          final isViewed = story['isViewed'] == true;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                // Get all stories from this user
                final userId = user['_id'] ?? user['id'];
                final userStories = stories
                    .where((s) {
                      final storyUser = s['user'] ?? {};
                      final storyUserId = storyUser['_id'] ?? storyUser['id'];
                      return storyUserId == userId;
                    })
                    .map((s) => Map<String, dynamic>.from(s))
                    .toList();
                
                // Find the index of the current story in the user's stories
                final initialIndex = userStories.indexWhere((s) => 
                  s['_id'] == story['_id'] || s['id'] == story['id']
                );
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StoryViewerPage(
                      userStories: userStories,
                      initialIndex: initialIndex >= 0 ? initialIndex : 0,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isViewed
                                ? null
                                : LinearGradient(
                                    colors: [
                                      Colors.purple.shade400,
                                      Colors.pink.shade400,
                                    ],
                                  ),
                            border: isViewed
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.3),
                                    width: 2,
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundImage: userAvatar != null
                                ? CachedNetworkImageProvider(
                                    UrlUtils.getFullAvatarUrl(userAvatar),
                                    maxWidth: 128, // Optimize avatar memory
                                    maxHeight: 128,
                                  )
                                : null,
                            child: userAvatar == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isViewed ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

