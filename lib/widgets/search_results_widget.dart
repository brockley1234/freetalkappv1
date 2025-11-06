import 'package:flutter/material.dart';
import '../services/search_service.dart';
import '../services/api_service.dart';
import '../utils/avatar_utils.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../pages/user_profile_page.dart';
import '../pages/post_detail_page.dart';

/// Reusable widget for displaying search results with filters and sorting
class SearchResultsWidget extends StatefulWidget {
  final String searchQuery;
  final String contentType; // 'users', 'posts', 'videos', 'stories', 'saved'
  final String sortBy;
  final SearchService searchService;

  const SearchResultsWidget({
    super.key,
    required this.searchQuery,
    required this.contentType,
    required this.sortBy,
    required this.searchService,
  });

  @override
  State<SearchResultsWidget> createState() => _SearchResultsWidgetState();
}

class _SearchResultsWidgetState extends State<SearchResultsWidget> {
  late Future<Map<String, dynamic>> _searchFuture;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  List<dynamic> _allResults = [];
  bool _isLoadingMore = false;
  bool _hasMore = true; // stops infinite scroll when the backend has no more
  int _searchGeneration = 0; // cancel-late-results token
  DateTime? _lastLoadMoreTime; // throttle load-more calls

  @override
  void initState() {
    super.initState();
    _performSearch();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(SearchResultsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery ||
        oldWidget.contentType != widget.contentType ||
        oldWidget.sortBy != widget.sortBy) {
      _currentPage = 1;
      _allResults.clear();
      _hasMore = true;
      _searchGeneration++; // invalidate prior searches
      _performSearch();
    }
  }

  void _performSearch() {
    _searchFuture = _executeSearch();
  }

  Future<Map<String, dynamic>> _executeSearch() async {
    switch (widget.contentType) {
      case 'users':
        return widget.searchService.searchUsers(
          widget.searchQuery,
          sortBy: widget.sortBy,
        );
      case 'posts':
        return widget.searchService.searchPosts(
          widget.searchQuery,
          sortBy: widget.sortBy,
          page: _currentPage,
        );
      case 'videos':
        return widget.searchService.searchVideos(
          widget.searchQuery,
          sortBy: widget.sortBy,
          page: _currentPage,
        );
      case 'stories':
        return widget.searchService.searchStories(
          widget.searchQuery,
        );
      case 'saved':
        return ApiService.searchSavedPosts(
          query: widget.searchQuery,
          page: _currentPage,
        );
      default:
        return {'success': false};
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return; // guard duplicates and end

    // throttle subsequent triggers near list end (e.g., bouncing)
    final now = DateTime.now();
    if (_lastLoadMoreTime != null &&
        now.difference(_lastLoadMoreTime!).inMilliseconds < 350) {
      return;
    }
    _lastLoadMoreTime = now;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final localGeneration = _searchGeneration;
      final result = await _executeSearch();
      if (!mounted || localGeneration != _searchGeneration) {
        // stale response, ignore
        return;
      }
      if (result['success'] == true) {
        setState(() {
          if (widget.contentType == 'users') {
            _allResults.addAll(result['data'] ?? []);
          } else if (widget.contentType == 'posts' ||
              widget.contentType == 'videos' ||
              widget.contentType == 'saved') {
            final key = widget.contentType == 'saved' ? 'posts' : widget.contentType;
            _allResults.addAll(result['data'][key] ?? []);
          }
          // Update hasMore if backend provides it, else infer using page size
          final dynamic meta = result['data'];
          final bool? serverHasMore = (meta is Map<String, dynamic>)
              ? (meta['hasMore'] as bool?)
              : null;
          if (serverHasMore != null) {
            _hasMore = serverHasMore;
          } else {
            // heuristic: if we received fewer than a typical page size, assume end
            const int inferredPageSize = 20;
            final int received = (widget.contentType == 'users')
                ? (result['data'] as List?)?.length ?? 0
                : ((result['data'][keyForType(widget.contentType)] as List?)?.length ?? 0);
            if (received < inferredPageSize) {
              _hasMore = false;
            }
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // Helper to map content type to the array key in API response
  String keyForType(String contentType) {
    if (contentType == 'saved') return 'posts';
    return contentType;
  }

  Future<void> _refresh() async {
    _currentPage = 1;
    _allResults.clear();
    _hasMore = true;
    _searchGeneration++;
    setState(() {
      _performSearch();
    });
    // Wait for first page to settle
    await _searchFuture;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Responsive spacing and sizing
    final listPadding = (screenWidth * 0.03).clamp(8.0, 16.0);
    final emptyStateIconSize = (screenWidth * 0.16).clamp(56.0, 80.0);
    final emptyStateTitleSize = (screenWidth * 0.04).clamp(16.0, 20.0);
    final emptyStateSubtitleSize = (screenWidth * 0.032).clamp(12.0, 16.0);
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all((screenWidth * 0.05).clamp(16.0, 24.0)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: (screenWidth * 0.12).clamp(40.0, 60.0),
                    height: (screenWidth * 0.12).clamp(40.0, 60.0),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                  SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: (screenWidth * 0.035).clamp(13.0, 16.0),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!['success']) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (screenWidth * 0.08).clamp(16.0, 32.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: emptyStateIconSize,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                  Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: emptyStateTitleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
                  Text(
                    'Try searching for something else',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: emptyStateSubtitleSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                  FilledButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!['data'];
        List<dynamic> results = [];

        if (widget.contentType == 'users') {
          results = data;
        } else if (widget.contentType == 'posts' ||
            widget.contentType == 'videos' ||
            widget.contentType == 'saved') {
          final key = widget.contentType == 'saved' ? 'posts' : widget.contentType;
          results = data[key] ?? [];
        } else if (widget.contentType == 'stories') {
          results = data['stories'] ?? [];
        }

        if (_allResults.isEmpty && results.isNotEmpty) {
          _allResults = List.from(results);
        }

        if (_allResults.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (screenWidth * 0.08).clamp(16.0, 32.0),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: emptyStateIconSize,
                    color: Colors.grey.shade300,
                  ),
                  SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                  Text(
                    'No ${widget.contentType} found',
                    style: TextStyle(
                      fontSize: emptyStateTitleSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final int extra = _isLoadingMore
            ? 1
            : (!_hasMore ? 1 : 0); // spinner or end-of-list footer

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(listPadding),
            itemCount: _allResults.length + extra,
            itemBuilder: (context, index) {
              // Loading spinner row
              if (_isLoadingMore && index == _allResults.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all((screenWidth * 0.04).clamp(12.0, 20.0)),
                    child: SizedBox(
                      width: (screenWidth * 0.1).clamp(32.0, 48.0),
                      height: (screenWidth * 0.1).clamp(32.0, 48.0),
                      child: const CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              // End-of-list footer
              if (!_isLoadingMore && !_hasMore && index == _allResults.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: (screenHeight * 0.02).clamp(12.0, 20.0),
                    ),
                    child: Text(
                      "You're all caught up",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: (screenWidth * 0.03).clamp(11.0, 13.0),
                      ),
                    ),
                  ),
                );
              }

            final item = _allResults[index];

              if (widget.contentType == 'users') {
                return KeyedSubtree(
                  key: ValueKey<String>(item['_id']?.toString() ?? 'user-$index'),
                  child: _buildUserResultTile(item, screenWidth, screenHeight),
                );
              } else if (widget.contentType == 'posts' ||
                  widget.contentType == 'saved') {
                return KeyedSubtree(
                  key: ValueKey<String>(item['_id']?.toString() ?? 'post-$index'),
                  child: _buildPostResultTile(item, screenWidth, screenHeight),
                );
              } else if (widget.contentType == 'videos') {
                return KeyedSubtree(
                  key: ValueKey<String>(item['_id']?.toString() ?? 'video-$index'),
                  child: _buildVideoResultTile(item, screenWidth, screenHeight),
                );
              } else if (widget.contentType == 'stories') {
                return KeyedSubtree(
                  key: ValueKey<String>(item['_id']?.toString() ?? 'story-$index'),
                  child: _buildStoryResultTile(item, screenWidth, screenHeight),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildUserResultTile(
    Map<String, dynamic> user,
    double screenWidth,
    double screenHeight,
  ) {
    final name = user['name'] ?? 'Unknown';
    final avatar = user['avatar'];
    final bio = user['bio'] ?? '';
    final followers = user['followersCount'] ?? 0;
    final isVerified = user['isVerified'] ?? false;
    final userId = user['_id'];
    final isFollowing = user['isFollowing'] ?? false;

    // Responsive sizing
    final avatarRadius = (screenWidth * 0.08).clamp(24.0, 36.0);
    final horizontalSpacing = (screenWidth * 0.03).clamp(8.0, 12.0);
    final verticalSpacing = (screenHeight * 0.008).clamp(4.0, 8.0);
    final nameTextSize = (screenWidth * 0.037).clamp(14.0, 17.0);
    final followersTextSize = (screenWidth * 0.03).clamp(11.0, 14.0);
    final bioTextSize = (screenWidth * 0.03).clamp(11.0, 13.0);
    final tilePadding = (screenHeight * 0.01).clamp(6.0, 12.0);

    return Material(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: userId),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tilePadding, horizontal: (screenWidth * 0.01).clamp(4.0, 6.0)),
          child: Row(
            children: [
              AvatarWithFallback(
                name: name,
                imageUrl: avatar,
                radius: avatarRadius,
                getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
              ),
              SizedBox(width: horizontalSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: nameTextSize,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified)
                          Padding(
                            padding: EdgeInsets.only(left: (screenWidth * 0.01).clamp(4.0, 6.0)),
                            child: Icon(
                              Icons.check_circle,
                              size: (screenWidth * 0.04).clamp(12.0, 18.0),
                              color: Colors.blue,
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: verticalSpacing),
                    Text(
                      '$followers followers',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: followersTextSize,
                      ),
                    ),
                    if (bio.isNotEmpty) ...[
                      SizedBox(height: (screenHeight * 0.005).clamp(4.0, 6.0)),
                      Text(
                        bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: bioTextSize,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: (screenWidth * 0.02).clamp(8.0, 12.0)),
              _buildFollowButton(userId, isFollowing, screenWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(String userId, bool isFollowing, double screenWidth) {
    final buttonPaddingH = (screenWidth * 0.03).clamp(10.0, 16.0);
    final buttonTextSize = (screenWidth * 0.032).clamp(11.0, 13.0);
    
    return FilledButton(
      onPressed: () => _handleFollowToggle(userId, isFollowing),
      style: FilledButton.styleFrom(
        backgroundColor: isFollowing ? Colors.grey.shade300 : Colors.blue,
        padding: EdgeInsets.symmetric(horizontal: buttonPaddingH),
      ),
      child: Text(
        isFollowing ? 'Following' : 'Follow',
        style: TextStyle(
          fontSize: buttonTextSize,
          color: isFollowing ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }

  Future<void> _handleFollowToggle(String userId, bool isCurrentlyFollowing) async {
    try {
      final result = isCurrentlyFollowing
          ? await ApiService.unfollowUser(userId)
          : await ApiService.followUser(userId);

      if (mounted && result['success'] == true) {
        // Find and update the user in _allResults
        final userIndex = _allResults.indexWhere((u) => u['_id'] == userId);
        if (userIndex != -1) {
          setState(() {
            _allResults[userIndex]['isFollowing'] = !isCurrentlyFollowing;
            // Update follower count
            if (!isCurrentlyFollowing) {
              _allResults[userIndex]['followersCount'] =
                  (_allResults[userIndex]['followersCount'] ?? 0) + 1;
            } else {
              _allResults[userIndex]['followersCount'] =
                  ((_allResults[userIndex]['followersCount'] ?? 0) - 1)
                      .clamp(0, double.infinity);
            }
          });
        }

        // Show feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFollowing ? '✅ Unfollowed' : '✅ Following',
            ),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showErrorDialog(result['message'] ?? 'Failed to update follow status');
      }
    } catch (e) {
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPostResultTile(
    Map<String, dynamic> post,
    double screenWidth,
    double screenHeight,
  ) {
    final author = post['author'] as Map<String, dynamic>? ?? {};
    final authorName = author['name'] ?? 'Unknown';
    final authorAvatar = author['profilePicture'];
    final content = post['content'] ?? '';
    final likesCount = post['likesCount'] ?? 0;
    final commentsCount = post['commentsCount'] ?? 0;
    final createdAt = post['createdAt'] ?? DateTime.now().toIso8601String();

    // Responsive sizing
    final avatarRadius = (screenWidth * 0.06).clamp(20.0, 28.0);
    final horizontalSpacing = (screenWidth * 0.03).clamp(8.0, 12.0);
    final authorNameSize = (screenWidth * 0.035).clamp(13.0, 16.0);
    final timeSize = (screenWidth * 0.03).clamp(11.0, 13.0);
    final contentSize = (screenWidth * 0.035).clamp(13.0, 15.0);
    final iconSize = (screenWidth * 0.04).clamp(14.0, 18.0);
    final statTextSize = (screenWidth * 0.03).clamp(11.0, 13.0);
    final tilePadding = (screenHeight * 0.01).clamp(6.0, 12.0);

    return Material(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(postId: post['_id']),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tilePadding, horizontal: (screenWidth * 0.01).clamp(4.0, 6.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarWithFallback(
                    name: authorName,
                    imageUrl: authorAvatar,
                    radius: avatarRadius,
                    getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
                  ),
                  SizedBox(width: horizontalSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: authorNameSize,
                          ),
                        ),
                        SizedBox(height: (screenHeight * 0.003).clamp(2.0, 4.0)),
                        Text(
                          _safeFormatTimeAgo(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: timeSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * 0.012).clamp(8.0, 16.0)),
              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: contentSize),
              ),
              SizedBox(height: (screenHeight * 0.012).clamp(8.0, 16.0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite_outline,
                          size: iconSize, color: Colors.grey.shade600),
                      SizedBox(width: (screenWidth * 0.01).clamp(4.0, 6.0)),
                      Text('$likesCount',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: statTextSize)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.message_outlined,
                          size: iconSize, color: Colors.grey.shade600),
                      SizedBox(width: (screenWidth * 0.01).clamp(4.0, 6.0)),
                      Text('$commentsCount',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: statTextSize)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.share_outlined,
                          size: iconSize, color: Colors.grey.shade600),
                      SizedBox(width: (screenWidth * 0.01).clamp(4.0, 6.0)),
                      Text('Share',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: statTextSize)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
              Divider(
                height: (screenHeight * 0.02).clamp(12.0, 16.0),
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoResultTile(
    Map<String, dynamic> video,
    double screenWidth,
    double screenHeight,
  ) {
    final author = video['author'] as Map<String, dynamic>? ?? {};
    final authorName = author['name'] ?? 'Unknown';
    final authorAvatar = author['profilePicture'];
    final title = video['title'] ?? 'Untitled';
    final thumbnail = video['thumbnail'];
    final views = video['views'] ?? 0;
    final createdAt = video['createdAt'] ?? DateTime.now().toIso8601String();

    // Responsive sizing
    final thumbnailWidth = (screenWidth * 0.22).clamp(70.0, 110.0);
    final thumbnailHeight = (screenWidth * 0.22).clamp(70.0, 110.0);
    final borderRadius = (screenWidth * 0.02).clamp(6.0, 12.0);
    final horizontalSpacing = (screenWidth * 0.03).clamp(8.0, 12.0);
    final authorAvatarRadius = (screenWidth * 0.045).clamp(16.0, 22.0);
    final authorNameSize = (screenWidth * 0.034).clamp(12.0, 15.0);
    final titleSize = (screenWidth * 0.034).clamp(12.0, 15.0);
    final metaSize = (screenWidth * 0.028).clamp(10.0, 12.0);
    final playIconSize = (screenWidth * 0.05).clamp(16.0, 24.0);
    final tilePadding = (screenHeight * 0.01).clamp(6.0, 12.0);

    return Material(
      child: InkWell(
        onTap: () {
          // Navigate to video detail
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tilePadding, horizontal: (screenWidth * 0.01).clamp(4.0, 6.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: thumbnailWidth,
                    height: thumbnailHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadius),
                      color: Colors.grey.shade200,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (thumbnail != null)
                          Image.network(
                            thumbnail,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.video_library,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          padding: EdgeInsets.all((screenWidth * 0.015).clamp(5.0, 8.0)),
                          child: Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: playIconSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: horizontalSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: titleSize,
                          ),
                        ),
                        SizedBox(height: (screenHeight * 0.004).clamp(3.0, 6.0)),
                        Text(
                          '$views views • ${_safeFormatTimeAgo(createdAt)}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: metaSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * 0.01).clamp(6.0, 10.0)),
              // Author section
              Row(
                children: [
                  AvatarWithFallback(
                    name: authorName,
                    imageUrl: authorAvatar,
                    radius: authorAvatarRadius,
                    getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
                  ),
                  SizedBox(width: (screenWidth * 0.02).clamp(6.0, 10.0)),
                  Expanded(
                    child: Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: authorNameSize,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
              Divider(
                height: (screenHeight * 0.02).clamp(12.0, 16.0),
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoryResultTile(
    Map<String, dynamic> story,
    double screenWidth,
    double screenHeight,
  ) {
    final author = story['author'] as Map<String, dynamic>? ?? {};
    final authorName = author['name'] ?? 'Unknown';
    final authorAvatar = author['profilePicture'];
    final content = story['content'] ?? '';
    final createdAt = story['createdAt'] ?? DateTime.now().toIso8601String();

    // Responsive sizing
    final avatarRadius = (screenWidth * 0.06).clamp(20.0, 28.0);
    final horizontalSpacing = (screenWidth * 0.03).clamp(8.0, 12.0);
    final authorNameSize = (screenWidth * 0.035).clamp(13.0, 16.0);
    final timeSize = (screenWidth * 0.03).clamp(11.0, 13.0);
    final contentSize = (screenWidth * 0.034).clamp(12.0, 15.0);
    final borderRadius = (screenWidth * 0.02).clamp(6.0, 10.0);
    final contentPadding = (screenWidth * 0.03).clamp(8.0, 12.0);
    final tilePadding = (screenHeight * 0.01).clamp(6.0, 12.0);

    return Material(
      child: InkWell(
        onTap: () {
          // Navigate to story detail
        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tilePadding, horizontal: (screenWidth * 0.01).clamp(4.0, 6.0)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AvatarWithFallback(
                    name: authorName,
                    imageUrl: authorAvatar,
                    radius: avatarRadius,
                    getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
                  ),
                  SizedBox(width: horizontalSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: authorNameSize,
                          ),
                        ),
                        SizedBox(height: (screenHeight * 0.003).clamp(2.0, 4.0)),
                        Text(
                          _safeFormatTimeAgo(createdAt),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: timeSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: (screenHeight * 0.012).clamp(8.0, 16.0)),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: EdgeInsets.all(contentPadding),
                child: Text(
                  content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: contentSize),
                ),
              ),
              SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
              Divider(
                height: (screenHeight * 0.02).clamp(12.0, 16.0),
                color: Colors.grey.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _safeFormatTimeAgo(dynamic createdAt) {
    try {
      return TimeUtils.formatTimeAgo(createdAt);
    } catch (_) {
      return '';
    }
  }
}
