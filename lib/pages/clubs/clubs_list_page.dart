import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/club_service.dart';
import '../../utils/app_logger.dart';
import 'club_detail_page.dart';

/// Clubs List Page - Browse and search clubs
/// 
/// Features:
/// - Search clubs by name
/// - Filter by category
/// - Pagination with infinite scroll
/// - Create new clubs
/// - Join/leave clubs
/// - Featured clubs section
/// - Smooth animations and skeleton loading
class ClubsListPage extends StatefulWidget {
  const ClubsListPage({super.key});

  @override
  State<ClubsListPage> createState() => _ClubsListPageState();
}

class _ClubsListPageState extends State<ClubsListPage> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _featuredClubs = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '';
  final ScrollController _scrollController = ScrollController();
  int _page = 1;
  static const int _limit = 20;
  bool _loadingMore = false;
  bool _hasMore = true;
  Timer? _searchDebounce;
  bool _showFeatured = true;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  // Available categories
  static const List<Map<String, dynamic>> _categories = [
    {'value': '', 'label': 'All', 'icon': Icons.apps},
    {'value': 'Sports', 'label': 'Sports', 'icon': Icons.sports_soccer},
    {'value': 'Music', 'label': 'Music', 'icon': Icons.music_note},
    {'value': 'Gaming', 'label': 'Gaming', 'icon': Icons.sports_esports},
    {'value': 'Technology', 'label': 'Technology', 'icon': Icons.computer},
    {'value': 'Art', 'label': 'Art', 'icon': Icons.palette},
    {'value': 'Food', 'label': 'Food', 'icon': Icons.restaurant},
    {'value': 'Travel', 'label': 'Travel', 'icon': Icons.flight},
    {'value': 'Education', 'label': 'Education', 'icon': Icons.school},
    {'value': 'Health', 'label': 'Health', 'icon': Icons.favorite},
    {'value': 'Entertainment', 'label': 'Entertainment', 'icon': Icons.movie},
    {'value': 'Books', 'label': 'Books', 'icon': Icons.book},
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _loadFeaturedClubs();
    _loadClubs(reset: true);
    _scrollController.addListener(_onScroll);
    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 400) {
      if (!_loadingMore && _hasMore && !_loading) {
        _loadNextPage();
      }
    }
  }

  Future<void> _loadFeaturedClubs() async {
    try {
      final res = await ClubService.featuredClubs(limit: 5);
      if (res['success'] == true && mounted) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        setState(() {
          _featuredClubs = items;
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load featured clubs', error: e);
    }
  }

  Future<void> _loadClubs({String q = '', String category = '', bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _items = [];
      });
    } else {
      setState(() { _loading = true; _error = null; });
    }
    
    try {
      final res = await ClubService.listClubs(
        q: q,
        category: category,
        page: _page,
        limit: _limit,
      );
      
      if (res['success'] == true) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        final hasMoreFromApi = data['hasMore'] == true;
        
        if (mounted) {
          setState(() {
            _items = items;
            _loading = false;
            _hasMore = hasMoreFromApi;
            _showFeatured = q.isEmpty && category.isEmpty && _page == 1;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = res['message'] ?? 'Failed to load clubs';
            _loading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load clubs', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) return;
    setState(() { _loadingMore = true; });
    
    try {
      final nextPage = _page + 1;
      final res = await ClubService.listClubs(
        q: _searchController.text.trim(),
        category: _selectedCategory,
        page: nextPage,
        limit: _limit,
      );
      
      if (res['success'] == true) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        final hasMoreFromApi = data['hasMore'] == true;
        
        if (mounted) {
          setState(() {
            _items = [..._items, ...items];
            _page = nextPage;
            _hasMore = hasMoreFromApi;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load next page', error: e);
    } finally {
      if (mounted) setState(() { _loadingMore = false; });
    }
  }

  Future<void> _joinClub(String id, String clubName) async {
    try {
      final res = await ClubService.joinClub(id);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? (res['message'] ?? 'Joined $clubName') : (res['message'] ?? 'Failed to join')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        _loadClubs(
          q: _searchController.text.trim(),
          category: _selectedCategory,
          reset: true,
        );
      }
    } catch (e) {
      AppLogger.e('Failed to join club', error: e);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _loadClubs(
        q: _searchController.text.trim(),
        category: _selectedCategory,
        reset: true,
      );
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadClubs(
      q: _searchController.text.trim(),
      category: category,
      reset: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'My Clubs',
            onPressed: () => _showMyClubs(colorScheme),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              onSubmitted: (v) => _loadClubs(
                q: v.trim(),
                category: _selectedCategory,
                reset: true,
              ),
              decoration: InputDecoration(
                hintText: 'Search clubs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadClubs(
                            q: '',
                            category: _selectedCategory,
                            reset: true,
                          );
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          
          // Category Filter
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat['value'];
                
                return FilterChip(
                  selected: selected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: selected ? colorScheme.onSecondaryContainer : null,
                      ),
                      const SizedBox(width: 4),
                      Text(cat['label'] as String),
                    ],
                  ),
                  onSelected: (value) => _onCategorySelected(cat['value'] as String),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  selectedColor: colorScheme.secondaryContainer,
                  showCheckmark: false,
                );
              },
            ),
          ),
          
          // Content
          Expanded(
            child: _loading
                ? _buildSkeletonLoader()
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                            const SizedBox(height: 16),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _loadClubs(
                                q: _searchController.text.trim(),
                                category: _selectedCategory,
                                reset: true,
                              ),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _loadFeaturedClubs();
                          await _loadClubs(
                            q: _searchController.text.trim(),
                            category: _selectedCategory,
                            reset: true,
                          );
                        },
                        child: _items.isEmpty && !_showFeatured
                            ? _buildEmptyState(theme, colorScheme)
                            : ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: (_showFeatured ? 1 : 0) + _items.length + (_loadingMore || _hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Featured section
                                  if (_showFeatured && index == 0) {
                                    return _buildFeaturedSection();
                                  }
                                  
                                  final adjustedIndex = _showFeatured ? index - 1 : index;
                                  
                                  // Loading indicator
                                  if (adjustedIndex >= _items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Center(child: CircularProgressIndicator()),
                                    );
                                  }
                                  
                                  // Club item with animation
                                  final club = _items[adjustedIndex];
                                  return _buildClubCard(club, adjustedIndex);
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton.extended(
          onPressed: _showCreateClubDialog,
          icon: const Icon(Icons.add),
          label: const Text('Create Club'),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.groups_outlined, size: 80, color: colorScheme.outline),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No clubs found',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Try a different search or category',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    if (_featuredClubs.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Featured Clubs',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _featuredClubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final club = _featuredClubs[index];
              return _buildFeaturedClubCard(club, index);
            },
          ),
        ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildFeaturedClubCard(Map<String, dynamic> club, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final joined = club['isMember'] == true;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClubDetailPage(clubId: club['_id']),
            ),
          );
          _loadClubs(q: _searchController.text.trim(), category: _selectedCategory, reset: true);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primaryContainer,
                colorScheme.secondaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.surface,
                    child: Icon(Icons.group, color: colorScheme.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.star, color: Colors.amber.shade700, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                club['name'] ?? '',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if ((club['category'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    club['category'].toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.people, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    '${club['membersCount'] ?? 0}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (joined)
                    Icon(Icons.check_circle, size: 18, color: Colors.green.shade600),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubCard(Map<String, dynamic> club, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final joined = club['isMember'] == true;
    final isAdmin = club['isAdmin'] == true;
    final isFeatured = club['isFeatured'] == true;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ClubDetailPage(clubId: club['_id']),
              ),
            );
            _loadClubs(q: _searchController.text.trim(), category: _selectedCategory, reset: true);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Hero(
                  tag: 'club-avatar-${club['_id']}',
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(Icons.group, size: 32, color: colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name with badges
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              club['name'] ?? '',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFeatured) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.star, size: 16, color: Colors.amber.shade700),
                          ],
                          if (isAdmin) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.admin_panel_settings, size: 16, color: colorScheme.primary),
                          ],
                        ],
                      ),
                      
                      // Description
                      if ((club['description'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          club['description'].toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      // Metadata
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Members count
                          Chip(
                            label: Text('${club['membersCount'] ?? 0} members'),
                            avatar: const Icon(Icons.people, size: 16),
                            padding: EdgeInsets.zero,
                            labelPadding: const EdgeInsets.only(left: 4, right: 8),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                          
                          // Category
                          if ((club['category'] ?? '').toString().isNotEmpty)
                            Chip(
                              label: Text(club['category'].toString()),
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colorScheme.tertiaryContainer,
                            ),
                          
                          // Privacy
                          if (club['privacy'] == 'private')
                            Chip(
                              label: const Text('Private'),
                              avatar: const Icon(Icons.lock, size: 14),
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.only(left: 2, right: 8),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colorScheme.errorContainer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action button
                const SizedBox(width: 12),
                if (joined)
                  Icon(Icons.check_circle, color: Colors.green.shade600, size: 28)
                else
                  FilledButton.tonal(
                    onPressed: () => _joinClub(club['_id'], club['name'] ?? 'Club'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(club['privacy'] == 'private' ? 'Request' : 'Join'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMyClubs(ColorScheme colorScheme) async {
    final res = await ClubService.myClubs();
    if (!mounted) return;
    
    if (res['success'] == true) {
      final data = Map<String, dynamic>.from(res['data'] ?? {});
      final myClubs = List<Map<String, dynamic>>.from(data['items'] ?? []);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('My Clubs'),
          content: SizedBox(
            width: double.maxFinite,
            child: myClubs.isEmpty
                ? const Center(child: Text('You haven\'t joined any clubs yet'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: myClubs.length,
                    itemBuilder: (context, index) {
                      final club = myClubs[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Icon(Icons.group, color: colorScheme.onPrimaryContainer),
                        ),
                        title: Text(club['name'] ?? ''),
                        subtitle: Text('${club['membersCount'] ?? 0} members'),
                        trailing: club['isAdmin'] == true
                            ? Icon(Icons.admin_panel_settings, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClubDetailPage(clubId: club['_id']),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showCreateClubDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final categoryController = TextEditingController();
    String privacy = 'public';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.group_add),
              SizedBox(width: 8),
              Text('Create Club'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Club Name *',
                    hintText: 'Enter club name (3-120 characters)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  maxLength: 120,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Tell us about your club',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  maxLength: 1000,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: '',
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat['value'] as String,
                      child: Row(
                        children: [
                          Icon(cat['icon'] as IconData, size: 20),
                          const SizedBox(width: 8),
                          Text(cat['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    categoryController.text = value ?? '';
                  },
                ),
                const SizedBox(height: 16),
                const Text('Privacy:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'public',
                      label: Text('Public'),
                      icon: Icon(Icons.public),
                    ),
                    ButtonSegment(
                      value: 'private',
                      label: Text('Private'),
                      icon: Icon(Icons.lock),
                    ),
                  ],
                  selected: {privacy},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      privacy = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  privacy == 'public' 
                    ? 'Anyone can join this club'
                    : 'Users need approval to join',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.length >= 3) {
                  Navigator.pop(
                    context,
                    {
                      'name': name,
                      'description': descriptionController.text.trim().isEmpty
                          ? null
                          : descriptionController.text.trim(),
                      'category': categoryController.text.trim().isEmpty
                          ? null
                          : categoryController.text.trim(),
                      'privacy': privacy,
                    },
                  );
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final res = await ClubService.createClub(
          name: result['name'] as String,
          description: result['description'] as String?,
          category: result['category'] as String?,
          privacy: result['privacy'] as String,
        );
        
        final ok = res['success'] == true;
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ok ? 'Club created successfully!' : (res['message'] ?? 'Failed to create club')),
                ),
              ],
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        if (ok) {
          await _loadFeaturedClubs();
          _loadClubs(reset: true);
        }
      } catch (e) {
        AppLogger.e('Failed to create club', error: e);
      }
    }
  }
}
