import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api_service.dart';
import '../utils/app_logger.dart';

/// Comprehensive search service with caching, history, and advanced features
class SearchService extends ChangeNotifier {
  static final SearchService _instance = SearchService._internal();

  factory SearchService() {
    return _instance;
  }

  SearchService._internal();

  // Search history
  List<String> _searchHistory = [];
  static const String _searchHistoryKey = 'search_history';
  static const int _maxSearchHistory = 20;

  // Cached search results
  final Map<String, dynamic> _searchCache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  final Map<String, DateTime> _cacheTimestamps = {};

  // Trending data
  List<dynamic> _trendingTopics = [];
  List<dynamic> _trendingUsers = [];
  List<dynamic> _trendingPosts = [];
  DateTime? _lastTrendingUpdate;
  static const Duration _trendingCacheDuration = Duration(hours: 1);

  // Search filters and preferences
  Map<String, dynamic> _searchFilters = {
    'contentType': 'all', // 'all', 'posts', 'videos', 'stories', 'users'
    'sortBy': 'relevance', // 'relevance', 'date', 'popularity'
    'timeRange': 'all', // 'all', 'today', 'week', 'month'
  };

  // Search analytics
  final Map<String, int> _searchFrequency = {};

  bool _isInitialized = false;

  // Getters
  List<String> get searchHistory => _searchHistory;
  List<dynamic> get trendingTopics => _trendingTopics;
  List<dynamic> get trendingUsers => _trendingUsers;
  List<dynamic> get trendingPosts => _trendingPosts;
  Map<String, dynamic> get searchFilters => _searchFilters;
  bool get isInitialized => _isInitialized;

  /// Initialize the search service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadSearchHistory();
      await _loadTrendingData();
      _isInitialized = true;
      notifyListeners();
      AppLogger().info('SearchService initialized');
    } catch (e) {
      AppLogger().error('Error initializing SearchService: $e');
    }
  }

  /// Load search history from device storage
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
      notifyListeners();
    } catch (e) {
      AppLogger().error('Error loading search history: $e');
    }
  }

  /// Save search history to device storage
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchHistoryKey, _searchHistory);
    } catch (e) {
      AppLogger().error('Error saving search history: $e');
    }
  }

  /// Add a search query to history
  void addToSearchHistory(String query) {
    query = query.trim();
    if (query.isEmpty) return;

    // Remove if already exists to avoid duplicates
    _searchHistory.removeWhere((item) => item.toLowerCase() == query.toLowerCase());

    // Add to front
    _searchHistory.insert(0, query);

    // Limit history size
    if (_searchHistory.length > _maxSearchHistory) {
      _searchHistory.removeRange(_maxSearchHistory, _searchHistory.length);
    }

    // Track search frequency
    _searchFrequency[query.toLowerCase()] = (_searchFrequency[query.toLowerCase()] ?? 0) + 1;

    _saveSearchHistory();
    notifyListeners();
  }

  /// Clear all search history
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Remove a specific item from search history
  Future<void> removeFromSearchHistory(String query) async {
    _searchHistory.removeWhere((item) => item == query);
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Load trending data
  Future<void> _loadTrendingData() async {
    try {
      // Check if cache is still valid
      if (_lastTrendingUpdate != null &&
          DateTime.now().difference(_lastTrendingUpdate!) < _trendingCacheDuration) {
        return;
      }

      // Fetch trending data in parallel
      final results = await Future.wait([
        _fetchTrendingTopics(),
        _fetchTrendingUsers(),
        _fetchTrendingPosts(),
      ], eagerError: true);

      _trendingTopics = results[0];
      _trendingUsers = results[1];
      _trendingPosts = results[2];
      _lastTrendingUpdate = DateTime.now();

      notifyListeners();
    } catch (e) {
      AppLogger().error('Error loading trending data: $e');
    }
  }

  /// Refresh trending data
  Future<void> refreshTrendingData() async {
    _lastTrendingUpdate = null; // Force refresh
    await _loadTrendingData();
  }

  /// Fetch trending topics
  Future<List<dynamic>> _fetchTrendingTopics() async {
    try {
      final result = await ApiService.getTrendingTopics();
      if (result['success']) {
        return result['data']['topics'] ?? [];
      }
      return [];
    } catch (e) {
      AppLogger().error('Error fetching trending topics: $e');
      return [];
    }
  }

  /// Fetch trending users
  Future<List<dynamic>> _fetchTrendingUsers() async {
    try {
      final result = await ApiService.getTopUsers();
      if (result['success']) {
        return result['data'] ?? [];
      }
      return [];
    } catch (e) {
      AppLogger().error('Error fetching trending users: $e');
      return [];
    }
  }

  /// Fetch trending posts
  Future<List<dynamic>> _fetchTrendingPosts() async {
    try {
      final result = await ApiService.getTrendingPosts();
      if (result['success']) {
        return result['data']['posts'] ?? [];
      }
      return [];
    } catch (e) {
      AppLogger().error('Error fetching trending posts: $e');
      return [];
    }
  }

  /// Comprehensive search across all content types
  Future<Map<String, dynamic>> universalSearch(
    String query, {
    String? contentType,
    String? sortBy,
    int page = 1,
    int limit = 20,
  }) async {
    query = query.trim();
    if (query.isEmpty) {
      return {
        'success': false,
        'message': 'Search query cannot be empty',
        'data': {}
      };
    }

    // Add to history
    addToSearchHistory(query);

    try {
      // Check cache
      final cacheKey = '${query}_${contentType}_$sortBy';
      if (_searchCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          AppLogger().info('Using cached search results for: $query');
          return {
            'success': true,
            'data': _searchCache[cacheKey],
            'cached': true
          };
        }
      }

      // Perform searches based on content type
      final Map<String, dynamic> results = {};

      if (contentType == null || contentType == 'all' || contentType == 'users') {
        results['users'] = await ApiService.searchUsers(
          query: query,
          limit: limit,
        );
      }

      if (contentType == null || contentType == 'all' || contentType == 'posts') {
        results['posts'] = await ApiService.searchPosts(
          query: query,
          page: page,
          limit: limit,
        );
      }

      if (contentType == null || contentType == 'all' || contentType == 'videos') {
        results['videos'] = await ApiService.searchVideos(
          query: query,
          page: page,
          limit: limit,
        );
      }

      if (contentType == null || contentType == 'all' || contentType == 'stories') {
        results['stories'] = await ApiService.searchStories(
          query: query,
        );
      }

      // Cache results
      _searchCache[cacheKey] = results;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return {
        'success': true,
        'data': results,
        'cached': false
      };
    } catch (e) {
      AppLogger().error('Error performing universal search: $e');
      return {
        'success': false,
        'message': 'Error performing search: $e',
        'data': {}
      };
    }
  }

  /// Search users with advanced filters
  Future<Map<String, dynamic>> searchUsers(
    String query, {
    String sortBy = 'relevance',
    int limit = 20,
  }) async {
    query = query.trim();
    if (query.isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    addToSearchHistory(query);

    try {
      final result = await ApiService.searchUsers(
        query: query,
        limit: limit,
      );

      // Sort results
      if (result['success'] && result['data'] != null) {
        List<dynamic> users = result['data'];
        _sortSearchResults(users, sortBy, 'user');
        result['data'] = users;
      }

      return result;
    } catch (e) {
      AppLogger().error('Error searching users: $e');
      return {'success': false, 'message': 'Error searching users: $e'};
    }
  }

  /// Search posts with advanced filters
  Future<Map<String, dynamic>> searchPosts(
    String query, {
    String sortBy = 'relevance',
    int page = 1,
    int limit = 20,
  }) async {
    query = query.trim();
    if (query.isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    addToSearchHistory(query);

    try {
      final result = await ApiService.searchPosts(
        query: query,
        page: page,
        limit: limit,
      );

      // Sort results
      if (result['success'] && result['data']['posts'] != null) {
        _sortSearchResults(result['data']['posts'], sortBy, 'post');
      }

      return result;
    } catch (e) {
      AppLogger().error('Error searching posts: $e');
      return {'success': false, 'message': 'Error searching posts: $e'};
    }
  }

  /// Search videos with advanced filters
  Future<Map<String, dynamic>> searchVideos(
    String query, {
    String sortBy = 'relevance',
    int page = 1,
    int limit = 20,
  }) async {
    query = query.trim();
    if (query.isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    addToSearchHistory(query);

    try {
      final result = await ApiService.searchVideos(
        query: query,
        page: page,
        limit: limit,
      );

      // Sort results
      if (result['success'] && result['data']['videos'] != null) {
        _sortSearchResults(result['data']['videos'], sortBy, 'video');
      }

      return result;
    } catch (e) {
      AppLogger().error('Error searching videos: $e');
      return {'success': false, 'message': 'Error searching videos: $e'};
    }
  }

  /// Search stories with advanced filters
  Future<Map<String, dynamic>> searchStories(
    String query, {
    String sortBy = 'relevance',
  }) async {
    query = query.trim();
    if (query.isEmpty) {
      return {'success': false, 'message': 'Search query cannot be empty'};
    }

    addToSearchHistory(query);

    try {
      final result = await ApiService.searchStories(query: query);

      // Sort results
      if (result['success'] && result['data'] != null) {
        _sortSearchResults(result['data'], sortBy, 'story');
      }

      return result;
    } catch (e) {
      AppLogger().error('Error searching stories: $e');
      return {'success': false, 'message': 'Error searching stories: $e'};
    }
  }

  /// Get search suggestions based on query and history
  Future<List<String>> getSearchSuggestions(String query) async {
    query = query.toLowerCase().trim();
    if (query.isEmpty) {
      // Return recent searches
      return _searchHistory.take(5).toList();
    }

    // Filter history by query
    final historySuggestions = _searchHistory
        .where((item) => item.toLowerCase().startsWith(query))
        .take(5)
        .toList();

    // Add trending suggestions from API
    try {
      final trendingSuggestions = await _fetchTrendingSuggestions(query);
      
      // Combine history and trending suggestions, avoiding duplicates
      final allSuggestions = <String>{
        ...historySuggestions,
        ...trendingSuggestions,
      };
      
      return allSuggestions.take(10).toList();
    } catch (e) {
      AppLogger().warning('Error fetching trending suggestions: $e');
      // Fall back to history suggestions if API fails
      return historySuggestions;
    }
  }

  /// Fetch trending suggestions from API
  Future<List<String>> _fetchTrendingSuggestions(String query) async {
    try {
      // Fetch trending topics that match the query
      final result = await ApiService.getTrendingTopics(limit: 20);
      
      if (result['success'] && result['data']['topics'] != null) {
        final topics = result['data']['topics'] as List<dynamic>;
        
        // Filter topics by matching the query
        final matchingSuggestions = topics
            .where((topic) {
              final tag = (topic['tag'] ?? topic['name'] ?? '').toString().toLowerCase();
              return tag.contains(query);
            })
            .map((topic) => (topic['tag'] ?? topic['name'] ?? '').toString())
            .toList();
        
        return matchingSuggestions;
      }
      
      return [];
    } catch (e) {
      AppLogger().error('Error fetching trending suggestions from API: $e');
      return [];
    }
  }

  /// Helper function to sort search results
  void _sortSearchResults(List<dynamic> results, String sortBy, String type) {
    switch (sortBy) {
      case 'date':
        results.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
        break;
      case 'popularity':
        results.sort((a, b) {
          int scoreA = 0;
          int scoreB = 0;

          if (type == 'user') {
            scoreA = (a['followersCount'] ?? 0) as int;
            scoreB = (b['followersCount'] ?? 0) as int;
          } else if (type == 'post' || type == 'video') {
            scoreA = ((a['likesCount'] ?? 0) as int) +
                ((a['commentsCount'] ?? 0) as int) * 2 +
                ((a['sharesCount'] ?? 0) as int) * 3;
            scoreB = ((b['likesCount'] ?? 0) as int) +
                ((b['commentsCount'] ?? 0) as int) * 2 +
                ((b['sharesCount'] ?? 0) as int) * 3;
          }

          return scoreB.compareTo(scoreA);
        });
        break;
      case 'relevance':
      default:
        // Results are already sorted by relevance from API
        break;
    }
  }

  /// Update search filters
  void updateSearchFilters(Map<String, dynamic> filters) {
    _searchFilters.addAll(filters);
    notifyListeners();
  }

  /// Clear search filters
  void resetSearchFilters() {
    _searchFilters = {
      'contentType': 'all',
      'sortBy': 'relevance',
      'timeRange': 'all',
    };
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _searchCache.clear();
    _cacheTimestamps.clear();
  }

  /// Get search analytics
  Map<String, int> getSearchAnalytics() {
    return Map.from(_searchFrequency);
  }

  /// Get popular searches from history
  List<String> getPopularSearches({int limit = 10}) {
    final entries = _searchFrequency.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).map((e) => e.key).toList();
  }
}
