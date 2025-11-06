import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _postsKey = 'cached_posts';
  static const String _postsCacheTimeKey = 'posts_cache_time';
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Cache posts
  Future<void> cachePosts(List<dynamic> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = json.encode(posts);
      await prefs.setString(_postsKey, postsJson);
      await prefs.setString(
        _postsCacheTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached posts
  Future<List<dynamic>?> getCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getString(_postsKey);
      final cacheTimeStr = prefs.getString(_postsCacheTimeKey);

      if (postsJson == null || cacheTimeStr == null) {
        return null;
      }

      // Check if cache is still valid
      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      if (now.difference(cacheTime) > _cacheValidDuration) {
        // Cache expired
        await clearPostsCache();
        return null;
      }

      final posts = json.decode(postsJson) as List<dynamic>;
      return posts;
    } catch (e) {
      return null;
    }
  }

  // Check if cache is valid
  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString(_postsCacheTimeKey);

      if (cacheTimeStr == null) return false;

      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      return now.difference(cacheTime) <= _cacheValidDuration;
    } catch (e) {
      return false;
    }
  }

  // Clear posts cache
  Future<void> clearPostsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_postsKey);
      await prefs.remove(_postsCacheTimeKey);
    } catch (e) {
      // Fail silently
    }
  }

  // Cache user profile
  Future<void> cacheUserProfile(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(user);
      await prefs.setString('cached_user_profile', userJson);
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached user profile
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('cached_user_profile');

      if (userJson == null) return null;

      return json.decode(userJson) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Cache notifications
  Future<void> cacheNotifications(List<dynamic> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = json.encode(notifications);
      await prefs.setString('cached_notifications', notificationsJson);
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached notifications
  Future<List<dynamic>?> getCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString('cached_notifications');

      if (notificationsJson == null) return null;

      return json.decode(notificationsJson) as List<dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Cache stories
  Future<void> cacheStories(List<dynamic> stories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storiesJson = json.encode(stories);
      await prefs.setString('cached_stories', storiesJson);
      await prefs.setString(
        'stories_cache_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached stories
  Future<List<dynamic>?> getCachedStories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storiesJson = prefs.getString('cached_stories');
      final cacheTimeStr = prefs.getString('stories_cache_time');

      if (storiesJson == null || cacheTimeStr == null) {
        return null;
      }

      // Check if cache is still valid (stories expire after 2 minutes)
      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      if (now.difference(cacheTime) > const Duration(minutes: 2)) {
        // Cache expired
        await prefs.remove('cached_stories');
        await prefs.remove('stories_cache_time');
        return null;
      }

      final stories = json.decode(storiesJson) as List<dynamic>;
      return stories;
    } catch (e) {
      return null;
    }
  }

  // Cache trending topics
  Future<void> cacheTrendingTopics(List<dynamic> topics) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topicsJson = json.encode(topics);
      await prefs.setString('cached_trending_topics', topicsJson);
      await prefs.setString(
        'trending_topics_cache_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached trending topics
  Future<List<dynamic>?> getCachedTrendingTopics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final topicsJson = prefs.getString('cached_trending_topics');
      final cacheTimeStr = prefs.getString('trending_topics_cache_time');

      if (topicsJson == null || cacheTimeStr == null) {
        return null;
      }

      // Check if cache is still valid (trending topics expire after 5 minutes)
      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      if (now.difference(cacheTime) > const Duration(minutes: 5)) {
        // Cache expired
        await prefs.remove('cached_trending_topics');
        await prefs.remove('trending_topics_cache_time');
        return null;
      }

      final topics = json.decode(topicsJson) as List<dynamic>;
      return topics;
    } catch (e) {
      return null;
    }
  }

  // Cache trending posts
  Future<void> cacheTrendingPosts(List<dynamic> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = json.encode(posts);
      await prefs.setString('cached_trending_posts', postsJson);
      await prefs.setString(
        'trending_posts_cache_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Fail silently - caching is not critical
    }
  }

  // Get cached trending posts
  Future<List<dynamic>?> getCachedTrendingPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getString('cached_trending_posts');
      final cacheTimeStr = prefs.getString('trending_posts_cache_time');

      if (postsJson == null || cacheTimeStr == null) {
        return null;
      }

      // Check if cache is still valid (trending posts expire after 5 minutes)
      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      if (now.difference(cacheTime) > const Duration(minutes: 5)) {
        // Cache expired
        await prefs.remove('cached_trending_posts');
        await prefs.remove('trending_posts_cache_time');
        return null;
      }

      final posts = json.decode(postsJson) as List<dynamic>;
      return posts;
    } catch (e) {
      return null;
    }
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    await clearPostsCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_profile');
    await prefs.remove('cached_notifications');
    await prefs.remove('cached_stories');
    await prefs.remove('stories_cache_time');
    await prefs.remove('prefetched_posts');
    await prefs.remove('prefetch_cache_time');
    await prefs.remove('cached_trending_topics');
    await prefs.remove('trending_topics_cache_time');
    await prefs.remove('cached_trending_posts');
    await prefs.remove('trending_posts_cache_time');
  }

  // Prefetch next page of posts
  Future<void> prefetchPosts(List<dynamic> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = json.encode(posts);
      await prefs.setString('prefetched_posts', postsJson);
      await prefs.setString(
        'prefetch_cache_time',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      // Fail silently
    }
  }

  // Get prefetched posts
  Future<List<dynamic>?> getPrefetchedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final postsJson = prefs.getString('prefetched_posts');
      final cacheTimeStr = prefs.getString('prefetch_cache_time');

      if (postsJson == null || cacheTimeStr == null) {
        return null;
      }

      // Check if prefetch cache is still valid (1 minute)
      final cacheTime = DateTime.parse(cacheTimeStr);
      final now = DateTime.now();
      if (now.difference(cacheTime) > const Duration(minutes: 1)) {
        // Cache expired
        await prefs.remove('prefetched_posts');
        await prefs.remove('prefetch_cache_time');
        await prefs.remove('cached_trending_topics');
        await prefs.remove('trending_topics_cache_time');
        return null;
      }

      final posts = json.decode(postsJson) as List<dynamic>;
      return posts;
    } catch (e) {
      return null;
    }
  }

  // Clear prefetch cache
  Future<void> clearPrefetchCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('prefetched_posts');
      await prefs.remove('prefetch_cache_time');
      await prefs.remove('cached_trending_topics');
      await prefs.remove('trending_topics_cache_time');
    } catch (e) {
      // Fail silently
    }
  }

  // Get cache size (approximate)
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      int totalSize = 0;
      int itemCount = 0;

      final keys = [
        'cached_posts',
        'cached_user_profile',
        'cached_notifications',
        'cached_stories',
        'prefetched_posts',
      ];

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          totalSize += value.length;
          itemCount++;
        }
      }

      return {
        'totalSize': totalSize,
        'itemCount': itemCount,
        'sizeInKB': (totalSize / 1024).toStringAsFixed(2),
        'sizeInMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'totalSize': 0,
        'itemCount': 0,
        'sizeInKB': '0.00',
        'sizeInMB': '0.00',
      };
    }
  }

  // Cache individual post for offline viewing
  Future<void> cachePostForOffline(Map<String, dynamic> post) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlinePostsJson = prefs.getString('offline_posts') ?? '[]';
      final offlinePosts = json.decode(offlinePostsJson) as List<dynamic>;

      // Check if post already cached
      final existingIndex = offlinePosts.indexWhere(
        (p) => p['_id'] == post['_id'],
      );

      if (existingIndex != -1) {
        offlinePosts[existingIndex] = post;
      } else {
        offlinePosts.add(post);
      }

      await prefs.setString('offline_posts', json.encode(offlinePosts));
    } catch (e) {
      // Fail silently
    }
  }

  // Get offline posts
  Future<List<dynamic>> getOfflinePosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlinePostsJson = prefs.getString('offline_posts') ?? '[]';
      return json.decode(offlinePostsJson) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  // Remove post from offline cache
  Future<void> removeOfflinePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlinePostsJson = prefs.getString('offline_posts') ?? '[]';
      final offlinePosts = json.decode(offlinePostsJson) as List<dynamic>;

      offlinePosts.removeWhere((p) => p['_id'] == postId);

      await prefs.setString('offline_posts', json.encode(offlinePosts));
    } catch (e) {
      // Fail silently
    }
  }

  // Clear offline posts
  Future<void> clearOfflinePosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_posts');
    } catch (e) {
      // Fail silently
    }
  }
}
