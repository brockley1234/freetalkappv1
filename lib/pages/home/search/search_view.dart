import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../utils/responsive_dimensions.dart';
import '../widgets/post_card_adapter.dart';
import '../widgets/user_search_result_card.dart';

/// Search view for finding users and posts
class SearchView extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Function(String userId) onUserTap;
  final Function(String postId) onPostTap;

  const SearchView({
    super.key,
    required this.currentUser,
    required this.onUserTap,
    required this.onPostTap,
  });

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Search results
  List<dynamic> _searchedUsers = [];
  List<dynamic> _searchedPosts = [];
  List<dynamic> _topUsers = [];

  // Loading states
  bool _isSearchingUsers = false;
  bool _isSearchingPosts = false;
  bool _isLoadingTopUsers = false;

  // Search filters
  String _searchFilter = 'all'; // 'all', 'people', 'posts'

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadTopUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTopUsers() async {
    if (_isLoadingTopUsers) return;

    setState(() {
      _isLoadingTopUsers = true;
    });

    try {
      final result = await ApiService.getTopUsers();
      if (result['success'] == true && mounted) {
        setState(() {
          _topUsers = result['data'] ?? [];
        });
      }
    } catch (e) {
      // Handle error silently
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTopUsers = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    // Debounce search
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _searchedUsers = [];
          _searchedPosts = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (_searchFilter == 'all' || _searchFilter == 'people') {
      _searchUsers(query);
    }
    if (_searchFilter == 'all' || _searchFilter == 'posts') {
      _searchPosts(query);
    }
  }

  Future<void> _searchUsers(String query) async {
    setState(() {
      _isSearchingUsers = true;
    });

    try {
      final result = await ApiService.searchUsers(query: query);
      if (result['success'] == true && mounted) {
        setState(() {
          _searchedUsers = result['data'] ?? [];
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingUsers = false;
        });
      }
    }
  }

  Future<void> _searchPosts(String query) async {
    setState(() {
      _isSearchingPosts = true;
    });

    try {
      final result = await ApiService.searchPosts(query: query);
      if (result['success'] == true && mounted) {
        setState(() {
          _searchedPosts = result['data'] ?? [];
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingPosts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Column(
      children: [
        _buildSearchBar(),
        _buildSearchFilters(),
        Expanded(
          child: _buildSearchResults(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search users and posts...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildSearchFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveDimensions.getHorizontalPadding(context),
      ),
      child: Row(
        children: [
          _buildFilterChip('All', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('People', 'people'),
          const SizedBox(width: 8),
          _buildFilterChip('Posts', 'posts'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _searchFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _searchFilter = value;
        });
        if (_searchQuery.isNotEmpty) {
          _performSearch(_searchQuery);
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return _buildDiscoverView();
    }

    final isLoading = _isSearchingUsers || _isSearchingPosts;
    final hasResults = _searchedUsers.isNotEmpty || _searchedPosts.isNotEmpty;

    if (isLoading && !hasResults) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
      children: [
        if (_searchedUsers.isNotEmpty && (_searchFilter == 'all' || _searchFilter == 'people')) ...[
          Text(
            'People',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ..._searchedUsers.map((user) => UserSearchResultCard(
                user: user,
                onTap: () => widget.onUserTap(user['_id']),
              )),
          const SizedBox(height: 24),
        ],
        if (_searchedPosts.isNotEmpty && (_searchFilter == 'all' || _searchFilter == 'posts')) ...[
          Text(
            'Posts',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ..._searchedPosts.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PostCardAdapter(
                  post: post,
                  currentUser: widget.currentUser,
                  onPostTap: () => widget.onPostTap(post['_id']),
                  onUserTap: () {
                    final author = post['author'];
                    if (author != null && author['_id'] != null) {
                      widget.onUserTap(author['_id']);
                    }
                  },
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildDiscoverView() {
    return ListView(
      padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
      children: [
        Text(
          'Discover People',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingTopUsers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_topUsers.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No users found',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        else
          ..._topUsers.map((user) => UserSearchResultCard(
                user: user,
                onTap: () => widget.onUserTap(user['_id']),
              )),
      ],
    );
  }
}

