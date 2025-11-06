import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../auth_wrapper.dart';
import '../pages/post_detail_page.dart';
import '../pages/highlight_detail_page.dart';
import '../pages/story_viewer_page.dart';
import '../pages/recover_pin_page.dart';
import '../services/api_service.dart';
import '../utils/app_logger.dart';

final _logger = AppLogger();

/// Global router configuration for the app
/// Handles deep links like:
/// - /post/[postId] -> Post detail page
/// - /profile/[userId] -> User profile page
/// - /messages -> Messages page
/// etc.

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  /// Initial route - handled by AuthWrapper
  initialLocation: '/',

  /// Error builder for unknown routes
  errorBuilder: (context, state) {
    _logger.error('Router error: ${state.uri.path}');
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.uri.path}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  },

  routes: [
    /// PIN reset page deep link (must be before root route to match first)
    /// URL format: /reset-pin?token=[resetToken]
    /// Example: https://freetalk.site/reset-pin?token=abc123...
    /// This route works even when not authenticated
    GoRoute(
      path: '/reset-pin',
      name: 'reset-pin',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        _logger.debug('🔐 Router: navigating to PIN reset with token: ${token != null ? '***' : 'none'}');

        // Navigate to RecoverPinPage with email method and token pre-filled
        return RecoverPinPage(
          method: 'email',
          initialToken: token,
        );
      },
    ),

    /// Root route - handled by AuthWrapper
    /// AuthWrapper will check authentication and show HomePage or LoginPage
    /// It also checks for pending deep links and navigates to them after auth
    GoRoute(
      path: '/',
      builder: (context, state) {
        _logger.debug('🏠 Router: initializing AuthWrapper');
        // Pass the initial location to AuthWrapper so it can handle deep links
        return AuthWrapper(initialDeepLink: state.uri.toString());
      },
    ),

    /// Post detail page deep link
    /// URL format: /post/[postId]
    /// Example: https://freetalk.site/post/123abc
    GoRoute(
      path: '/post/:postId',
      name: 'post-detail',
      builder: (context, state) {
        final postId = state.pathParameters['postId'];
        _logger.debug('📄 Router: navigating to post $postId');

        if (postId == null || postId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Text('Invalid post ID'),
            ),
          );
        }

        // Return PostDetailPage directly
        // If not authenticated, GoRouter will redirect to / which shows login
        return PostDetailPage(
          postId: postId,
        );
      },
    ),

    /// Highlight detail page deep link
    /// URL format: /highlight/[highlightId]
    /// Example: https://freetalk.site/highlight/123abc
    GoRoute(
      path: '/highlight/:highlightId',
      name: 'highlight-detail',
      builder: (context, state) {
        final highlightId = state.pathParameters['highlightId'];
        _logger.debug('✨ Router: navigating to highlight $highlightId');

        if (highlightId == null || highlightId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Text('Invalid highlight ID'),
            ),
          );
        }

        return HighlightDetailPage(
          highlightId: highlightId,
        );
      },
    ),

    /// Story viewer page
    /// URL format: /story/[storyId]?highlight=[highlightId]&index=[storyIndex]
    /// Example: https://freetalk.site/story/123abc?highlight=456def&index=0
    GoRoute(
      path: '/story/:storyId',
      name: 'story-viewer',
      builder: (context, state) {
        final storyId = state.pathParameters['storyId'];
        final highlightId = state.uri.queryParameters['highlight'];
        final storyIndex = int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;
        
        _logger.debug('📖 Router: navigating to story $storyId (highlight: $highlightId, index: $storyIndex)');

        if (storyId == null || storyId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: const Center(
              child: Text('Invalid story ID'),
            ),
          );
        }

        // Return StoryViewerPage - it will fetch and display the story
        // The page expects a list of stories, so we pass a single story wrapped in a list
        return _StoryViewerPageWrapper(
          storyId: storyId,
          highlightId: highlightId,
          initialIndex: storyIndex,
        );
      },
    ),
  ],
);

/// Wrapper widget that fetches the story and its highlight stories for viewing
class _StoryViewerPageWrapper extends StatefulWidget {
  final String storyId;
  final String? highlightId;
  final int initialIndex;

  const _StoryViewerPageWrapper({
    required this.storyId,
    this.highlightId,
    this.initialIndex = 0,
  });

  @override
  State<_StoryViewerPageWrapper> createState() =>
      _StoryViewerPageWrapperState();
}

class _StoryViewerPageWrapperState extends State<_StoryViewerPageWrapper> {
  late Future<List<Map<String, dynamic>>> _storiesFuture;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  void _loadStories() {
    _storiesFuture = _fetchStories();
  }

  Future<List<Map<String, dynamic>>> _fetchStories() async {
    try {
      // If we have a highlight ID, fetch all stories from that highlight
      if (widget.highlightId != null && widget.highlightId!.isNotEmpty) {
        final result =
            await ApiService.getHighlightDetail(widget.highlightId!);
        if (result['success'] == true) {
          final highlightData = result['data'] as Map<String, dynamic>;
          final stories =
              (highlightData['stories'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          
          // Find the index of the story we want to display
          int targetIndex = 0;
          for (int i = 0; i < stories.length; i++) {
            if (stories[i]['_id'] == widget.storyId) {
              targetIndex = i;
              break;
            }
          }
          
          // Reorder the list so the target story is at the beginning
          if (targetIndex > 0 && stories.isNotEmpty) {
            final story = stories.removeAt(targetIndex);
            stories.insert(0, story);
          }
          
          return stories;
        }
      }

      // Fallback: fetch just this story
      final result = await ApiService.getStory(widget.storyId);
      if (result['success'] == true) {
        final storyData = result['data'] as Map<String, dynamic>;
        return [storyData];
      }

      return [];
    } catch (e) {
      _logger.error('❌ Error fetching stories for viewer: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _storiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text('Story not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        return StoryViewerPage(
          userStories: snapshot.data!,
          initialIndex: 0, // We already reordered the list above
        );
      },
    );
  }
}

