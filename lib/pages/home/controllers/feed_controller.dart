import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/cache_service.dart';
import '../../../services/socket_service.dart';
import '../../../utils/app_logger.dart';
import '../../../widgets/feed_filter_selector.dart';

/// Controller for managing feed state and data
class FeedController extends ChangeNotifier {
  // State
  List<dynamic> _posts = [];
  int _currentPage = 1;
  bool _hasMorePosts = true;
  bool _isLoadingPosts = false;
  bool _hasError = false;
  String? _errorMessage;
  
  // Feed filtering and sorting
  FeedFilterType _selectedFilter = FeedFilterType.all;
  FeedSortType _selectedSort = FeedSortType.newest;
  
  // Constants
  static const int _maxCachedPosts = 100;
  static const int _postsPerPage = 10;
  
  // Performance helpers
  final Map<String, dynamic> _pendingUpdates = {};
  Timer? _batchUpdateTimer;
  
  // Socket listeners
  Function(dynamic)? _postCreatedListener;
  Function(dynamic)? _postReactedListener;
  Function(dynamic)? _postCommentedListener;
  Function(dynamic)? _postDeletedListener;
  Function(dynamic)? _postUpdatedListener;
  Function(dynamic)? _postSharedListener;
  
  // Getters
  List<dynamic> get posts => _posts;
  bool get isLoading => _isLoadingPosts;
  bool get hasMore => _hasMorePosts;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  FeedFilterType get selectedFilter => _selectedFilter;
  FeedSortType get selectedSort => _selectedSort;
  
  FeedController() {
    _setupSocketListeners();
  }
  
  /// Initialize feed by loading cached data first, then fresh data
  Future<void> initialize() async {
    await _loadCachedPosts();
    await loadPosts(refresh: true);
  }
  
  /// Load cached posts for instant display
  Future<void> _loadCachedPosts() async {
    try {
      final cacheService = CacheService();
      final cachedPosts = await cacheService.getCachedPosts();
      
      if (cachedPosts != null && cachedPosts.isNotEmpty) {
        _posts = cachedPosts;
        notifyListeners();
      }
    } catch (e) {
      AppLogger.e('Error loading cached posts: $e');
    }
  }
  
  /// Load posts from API
  Future<void> loadPosts({bool refresh = false}) async {
    if (_isLoadingPosts || (!_hasMorePosts && !refresh)) return;
    
    if (refresh) {
      _currentPage = 1;
      _hasMorePosts = true;
      _posts.clear();
    }
    
    _isLoadingPosts = true;
    _hasError = false;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final filterParam = _getFilterString(_selectedFilter);
      final sortParam = _getSortString(_selectedSort);
      
      final result = await ApiService.getPosts(
        page: _currentPage,
        limit: _postsPerPage,
        filter: filterParam,
        sort: sortParam,
      );
      
      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> newPosts = result['data']['posts'];
        final pagination = result['data']['pagination'];
        
        if (refresh) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        
        // Memory management: limit posts in memory
        if (_posts.length > _maxCachedPosts) {
          _posts = _posts.sublist(0, _maxCachedPosts);
        }
        
        _currentPage++;
        _hasMorePosts = pagination['page'] < pagination['pages'];
        
        // Cache posts for offline access
        _cachePosts();
      } else {
        _hasError = true;
        _errorMessage = result['message'] ?? 'Failed to load posts';
      }
    } catch (e) {
      AppLogger.e('Error loading posts: $e');
      _hasError = true;
      _errorMessage = 'Network error: ${e.toString()}';
    } finally {
      _isLoadingPosts = false;
      notifyListeners();
    }
  }
  
  /// Refresh feed
  Future<void> refresh() async {
    await loadPosts(refresh: true);
  }
  
  /// Update feed filter
  void setFilter(FeedFilterType filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      notifyListeners();
      refresh();
    }
  }
  
  /// Update feed sort
  void setSort(FeedSortType sort) {
    if (_selectedSort != sort) {
      _selectedSort = sort;
      notifyListeners();
      refresh();
    }
  }
  
  /// Cache posts for offline access
  Future<void> _cachePosts() async {
    try {
      final cacheService = CacheService();
      await cacheService.cachePosts(_posts);
    } catch (e) {
      AppLogger.e('Error caching posts: $e');
    }
  }
  
  /// Setup socket listeners for real-time updates
  void _setupSocketListeners() {
    final socketService = SocketService();
    
    // Listen for new posts
    _postCreatedListener = (data) {
      if (data != null && data['post'] != null) {
        final newPost = data['post'];
        final postId = newPost['_id'];
        
        // Check if post already exists (prevent duplicates)
        final exists = _posts.any((p) => p['_id'] == postId);
        if (!exists) {
          _posts.insert(0, newPost);
          
          // Limit posts in memory
          if (_posts.length > _maxCachedPosts) {
            _posts.removeLast();
          }
          
          notifyListeners();
        }
      }
    };
    socketService.on('post:created', _postCreatedListener!);
    
    // Listen for post reactions (use batching for better performance)
    _postReactedListener = (data) {
      if (data != null && data['postId'] != null) {
        final updates = <String, dynamic>{};
        if (data['reactionsCount'] != null) {
          updates['reactionsCount'] = data['reactionsCount'];
        }
        if (data['reactions'] != null) {
          updates['reactions'] = data['reactions'];
        }
        if (data['reactionsSummary'] != null) {
          updates['reactionsSummary'] = data['reactionsSummary'];
        }
        _batchUpdate(data['postId'], updates);
      }
    };
    socketService.on('post:reacted', _postReactedListener!);
    
    // Listen for post comments (use batching for better performance)
    _postCommentedListener = (data) {
      if (data != null && data['postId'] != null) {
        final updates = <String, dynamic>{};
        if (data['commentsCount'] != null) {
          updates['commentsCount'] = data['commentsCount'];
        }
        if (data['topComments'] != null) {
          updates['topComments'] = data['topComments'];
        }
        _batchUpdate(data['postId'], updates);
      }
    };
    socketService.on('post:commented', _postCommentedListener!);
    
    // Listen for post deletions
    _postDeletedListener = (data) {
      if (data != null && data['postId'] != null) {
        _posts.removeWhere((p) => p['_id'] == data['postId']);
        notifyListeners();
      }
    };
    socketService.on('post:deleted', _postDeletedListener!);
    
    // Listen for post updates
    _postUpdatedListener = (data) {
      if (data != null && data['post'] != null) {
        final updatedPost = data['post'];
        _updatePostInFeed(updatedPost['_id'], (post) {
          post.addAll(updatedPost);
        });
      }
    };
    socketService.on('post:updated', _postUpdatedListener!);
    
    // Listen for post shares (use batching for better performance)
    _postSharedListener = (data) {
      if (data != null && data['postId'] != null) {
        final updates = <String, dynamic>{};
        if (data['sharesCount'] != null) {
          updates['sharesCount'] = data['sharesCount'];
        }
        _batchUpdate(data['postId'], updates);
      }
    };
    socketService.on('post:shared', _postSharedListener!);
  }
  
  /// Batch multiple updates together for better performance
  void _batchUpdate(String postId, Map<String, dynamic> updates) {
    // Store pending update
    if (_pendingUpdates.containsKey(postId)) {
      // Merge with existing update
      _pendingUpdates[postId]!.addAll(updates);
    } else {
      _pendingUpdates[postId] = updates;
    }
    
    // Cancel existing timer and create new one
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 300), () {
      _applyBatchedUpdates();
    });
  }
  
  /// Apply all batched updates at once
  void _applyBatchedUpdates() {
    if (_pendingUpdates.isEmpty) return;
    
    bool hasChanges = false;
    
    for (var entry in _pendingUpdates.entries) {
      final postId = entry.key;
      final updates = entry.value;
      final index = _posts.indexWhere((p) => p['_id'] == postId);
      
      if (index != -1) {
        _posts[index].addAll(updates);
        hasChanges = true;
      }
    }
    
    _pendingUpdates.clear();
    
    if (hasChanges) {
      notifyListeners();
    }
  }
  
  /// Update a specific post in the feed
  void _updatePostInFeed(String postId, Function(Map<String, dynamic>) updater) {
    final index = _posts.indexWhere((p) => p['_id'] == postId);
    if (index != -1) {
      updater(_posts[index]);
      notifyListeners();
    }
  }
  
  /// Convert filter enum to API string
  String _getFilterString(FeedFilterType filter) {
    switch (filter) {
      case FeedFilterType.all:
        return 'all';
      case FeedFilterType.following:
        return 'following';
      case FeedFilterType.trending:
        return 'trending';
      default:
        return 'all';
    }
  }
  
  /// Convert sort enum to API string
  String _getSortString(FeedSortType sort) {
    switch (sort) {
      case FeedSortType.newest:
        return 'newest';
      case FeedSortType.trending:
        return 'trending';
      default:
        return 'newest';
    }
  }
  
  @override
  void dispose() {
    _batchUpdateTimer?.cancel();
    _pendingUpdates.clear();
    
    // Clean up socket listeners
    final socketService = SocketService();
    if (_postCreatedListener != null) {
      socketService.off('post:created', _postCreatedListener);
    }
    if (_postReactedListener != null) {
      socketService.off('post:reacted', _postReactedListener);
    }
    if (_postCommentedListener != null) {
      socketService.off('post:commented', _postCommentedListener);
    }
    if (_postDeletedListener != null) {
      socketService.off('post:deleted', _postDeletedListener);
    }
    if (_postUpdatedListener != null) {
      socketService.off('post:updated', _postUpdatedListener);
    }
    if (_postSharedListener != null) {
      socketService.off('post:shared', _postSharedListener);
    }
    
    super.dispose();
  }
}

