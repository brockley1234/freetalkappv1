import 'package:flutter/material.dart';
import '../widgets/page_transition_wrapper.dart';
import '../widgets/shimmer_loader.dart';
import '../widgets/message_bubble_animation.dart';
import '../widgets/like_animation.dart';
import '../utils/app_logger.dart';

/// Example integration of all animation widgets into chat page
///
/// This file demonstrates best practices for using the new animation widgets
/// in the FreeTalk app. Copy-paste the relevant sections into your pages.

// ============================================================================
// EXAMPLE 1: PAGE TRANSITIONS
// ============================================================================
/// Use this in navigation instead of Navigator.push()
///
/// Old way:
///   Navigator.push(context, MaterialPageRoute(builder: (context) => ChatPage(...)));
///
/// New way with animations:
///   navigateTo(context, (context) => ChatPage(...), transitionType: TransitionType.slideRight);

class AnimationIntegrationExample extends StatelessWidget {
  const AnimationIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Example 1: Navigate with slide transition
            ElevatedButton(
              onPressed: () {
                navigateTo(
                  context,
                  (context) => const Scaffold(
                    body: Center(child: Text('Next Page')),
                  ),
                  transitionType: TransitionType.slideRight,
                );
              },
              child: const Text('Slide Right'),
            ),

            // Example 2: Navigate with fade + scale
            ElevatedButton(
              onPressed: () {
                navigateTo(
                  context,
                  (context) => const Scaffold(
                    body: Center(child: Text('Next Page')),
                  ),
                  transitionType: TransitionType.fadeScale,
                );
              },
              child: const Text('Fade Scale'),
            ),

            // ================================================================
            // EXAMPLE 2: LOADING SKELETONS
            // ================================================================
            // Use ShimmerLoader when fetching data

            const SizedBox(height: 20),
            const Text('Skeleton Loading:'),
            const PostSkeletonLoader(),
            const PostSkeletonLoader(),

            // Or for messages:
            const SizedBox(height: 20),
            const Text('Message Skeleton:'),
            const MessageSkeletonLoader(),

            // ================================================================
            // EXAMPLE 3: ANIMATED MESSAGES
            // ================================================================
            // Replace static message bubbles with AnimatedMessageBubble

            const SizedBox(height: 20),
            AnimatedMessageBubble(
              message: 'Hello! This message has a cool animation!',
              isFromMe: false,
              senderName: 'John',
              timestamp: DateTime.now(),
            ),
            AnimatedMessageBubble(
              message: 'I can reply too! 🎉',
              isFromMe: true,
              timestamp: DateTime.now(),
            ),

            // Typing indicator
            const SizedBox(height: 20),
            const TypingIndicator(),

            // ================================================================
            // EXAMPLE 4: ANIMATED LIKE BUTTON
            // ================================================================

            const SizedBox(height: 20),
            // Stateful version (manages its own state)
            const _LikeButtonExample(),

            // Double-tap to like
            const SizedBox(height: 20),
            DoubleTapLike(
              onLike: () => AppLogger().info('Liked!'),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Double tap to like!',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LikeButtonExample extends StatefulWidget {
  const _LikeButtonExample();

  @override
  State<_LikeButtonExample> createState() => _LikeButtonExampleState();
}

class _LikeButtonExampleState extends State<_LikeButtonExample> {
  bool _isLiked = false;
  int _likeCount = 42;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedLikeButton(
          isLiked: _isLiked,
          likeCount: _likeCount,
          onPressed: () {
            setState(() {
              if (_isLiked) {
                _likeCount--;
              } else {
                _likeCount++;
              }
              _isLiked = !_isLiked;
            });
          },
        ),
        const SizedBox(width: 12),
        AnimatedLikeCounter(
          count: _likeCount,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ============================================================================
// INTEGRATION CHECKLIST
// ============================================================================
/*

1. PAGE TRANSITIONS
   - In navigation code, replace:
     Navigator.push(context, MaterialPageRoute(...))
   - With:
     navigateTo(context, (context) => MyPage(), transitionType: TransitionType.slideRight)
   - Common pages to update:
     * Login → HomePage
     * HomePage → PostDetail
     * HomePage → ProfilePage
     * ChatList → ChatPage
     * PostDetail → UserProfile

2. LOADING STATES
   - In build() methods, wrap content with ShimmerLoader:
     ShimmerLoader(
       isLoading: _isLoading,
       child: PostCard(),
     )
   - Or use specific skeleton loaders:
     * PostSkeletonLoader() - for feed
     * MessageSkeletonLoader() - for chat
     * ContainerSkeleton() - for custom content

3. MESSAGE ANIMATIONS
   - Replace static message bubbles in chat_page.dart
   - Instead of:
     buildMessageBubble()
   - Use:
     AnimatedMessageBubble(
       message: msg['content'],
       isFromMe: msg['senderId'] == currentUserId,
       timestamp: DateTime.parse(msg['createdAt']),
     )
   - Add typing indicator when other user types:
     if (isTyping) TypingIndicator()

4. LIKE ANIMATIONS
   - In post cards, replace standard icon button:
     Old:
       IconButton(icon: Icon(Icons.favorite), onPressed: () {...})
     New:
       AnimatedLikeButton(
         isLiked: post.isLiked,
         likeCount: post.likeCount,
         onPressed: () => likePost(post.id),
       )
   - Or use DoubleTapLike for images/content:
     DoubleTapLike(
       onLike: () => likePost(id),
       child: Image.network(url),
     )

5. FILES TO UPDATE
   - freetalk/lib/pages/chat_page.dart
     * Replace message bubble rendering
     * Add typing indicator
     * Wrap with ShimmerLoader during loading
   
   - freetalk/lib/pages/homepage.dart
     * Add page transitions to navigation
     * Wrap posts with ShimmerLoader
     * Add AnimatedLikeButton to post cards
   
   - freetalk/lib/pages/post_detail_page.dart
     * AnimatedLikeButton for post likes
     * AnimatedMessageBubble for comments
   
   - freetalk/lib/pages/conversations_page.dart
     * Page transition to ChatPage
     * ShimmerLoader during load
   
   - freetalk/lib/pages/user_profile_page.dart
     * Page transitions
     * AnimatedLikeButton for profile posts
     * ShimmerLoader for profile data

*/
