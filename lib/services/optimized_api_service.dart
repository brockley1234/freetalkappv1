import 'api_service.dart';
import 'network_optimization_service.dart';
import '../utils/app_logger.dart';

/// Optimized API service wrapper that adds network optimization
/// This wrapper should be used alongside the existing ApiService
class OptimizedApiService {
  static final OptimizedApiService _instance = OptimizedApiService._internal();
  final NetworkOptimizationService _networkOpt = NetworkOptimizationService();

  factory OptimizedApiService() {
    return _instance;
  }

  OptimizedApiService._internal();

  /// Get posts with request deduplication and smart caching
  Future<Map<String, dynamic>> getPosts({
    required int page,
    required int limit,
  }) async {
    final key = 'getPosts_page_$page-limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching posts: page=$page, limit=$limit');
      return ApiService.getPosts(page: page, limit: limit);
    });
  }

  /// Get trending topics with deduplication
  /// Requests made within 500ms will return the same cached result
  Future<Map<String, dynamic>> getTrendingTopics() async {
    const key = 'getTrendingTopics';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching trending topics');
      return ApiService.getTrendingTopics();
    });
  }

  /// Get trending posts with deduplication
  Future<Map<String, dynamic>> getTrendingPosts({
    required int page,
    required int limit,
  }) async {
    final key = 'getTrendingPosts_page_$page-limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching trending posts: page=$page, limit=$limit');
      return ApiService.getTrendingPosts(page: page, limit: limit);
    });
  }

  /// Get stories with deduplication
  Future<Map<String, dynamic>> getStories() async {
    const key = 'getStories';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching stories');
      return ApiService.getStories();
    });
  }

  /// Get notifications with deduplication
  Future<Map<String, dynamic>> getNotifications({
    required int page,
    required int limit,
  }) async {
    final key = 'getNotifications_page_$page-limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching notifications: page=$page, limit=$limit');
      return ApiService.getNotifications(page: page, limit: limit);
    });
  }

  /// Get current user with deduplication
  Future<Map<String, dynamic>> getCurrentUser() async {
    const key = 'getCurrentUser';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching current user');
      return ApiService.getCurrentUser();
    });
  }

  /// Get suggested users with deduplication
  Future<Map<String, dynamic>> getSuggestedUsers({required int limit}) async {
    final key = 'getSuggestedUsers_limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching suggested users: limit=$limit');
      return ApiService.getSuggestedUsers(limit: limit);
    });
  }

  /// Get top users with deduplication
  Future<Map<String, dynamic>> getTopUsers({required int limit}) async {
    final key = 'getTopUsers_limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching top users: limit=$limit');
      return ApiService.getTopUsers(limit: limit);
    });
  }

  /// Get top follower posts with deduplication
  Future<Map<String, dynamic>> getTopFollowerPosts({required int limit}) async {
    final key = 'getTopFollowerPosts_limit_$limit';

    return _networkOpt.deduplicateRequest(key, () async {
      AppLogger().debug('📥 Fetching top follower posts: limit=$limit');
      return ApiService.getTopFollowerPosts(limit: limit);
    });
  }

  /// Batch react to posts - combines multiple reactions into one request
  void batchReactToPost(
    String postId,
    String reactionType,
  ) {
    _networkOpt.batchRequest(
      'batch_post_reactions',
      {
        'postId': postId,
        'reactionType': reactionType,
      },
      (batch) async {
        try {
          AppLogger()
              .debug('📦 Processing batch of ${batch.length} post reactions');
          // Batch items can be processed individually or sent to a batch endpoint
          // if your backend supports it
          for (var item in batch) {
            // Call your reaction API - adjust method name as needed
            // await ApiService.addReaction(
            //   postId: item['postId'],
            //   reactionType: item['reactionType'],
            // );
            AppLogger().debug(
              'Processing reaction: ${item['postId']} - ${item['reactionType']}',
            );
          }
        } catch (e) {
          AppLogger().error('Error processing batch reactions', error: e);
        }
      },
    );
  }

  /// Get network optimization statistics
  Map<String, dynamic> getOptimizationStats() {
    return _networkOpt.getStats();
  }

  /// Clear optimization state (call on logout)
  void clear() {
    _networkOpt.clear();
  }
}
