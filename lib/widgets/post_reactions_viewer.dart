import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../pages/user_profile_page.dart';

class PostReactionsViewer extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> reactionsSummary;

  const PostReactionsViewer({
    super.key,
    required this.postId,
    required this.reactionsSummary,
  });

  @override
  State<PostReactionsViewer> createState() => _PostReactionsViewerState();
}

class _PostReactionsViewerState extends State<PostReactionsViewer>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, List<dynamic>> _reactionsByType = {};
  List<dynamic> _allReactions = [];

  final Map<String, String> _reactionEmojis = {
    'like': '👍',
    'celebrate': '🎉',
    'insightful': '💡',
    'funny': '😄',
    'mindblown': '🤯',
    'support': '❤️',
  };

  @override
  void initState() {
    super.initState();
    _setupTabs();
    _loadReactions();
  }

  void _setupTabs() {
    // Count how many reaction types are present
    final activeReactions = widget.reactionsSummary.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    _tabController = TabController(
      length: activeReactions.length + 1, // +1 for "All" tab
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReactions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getPostReactions(widget.postId);

      if (result['success'] == true && result['data'] != null) {
        final reactions = result['data']['reactions'] as List<dynamic>;

        // Group reactions by type
        final Map<String, List<dynamic>> grouped = {};
        for (final reaction in reactions) {
          final type = reaction['type'] as String;
          if (!grouped.containsKey(type)) {
            grouped[type] = [];
          }
          grouped[type]!.add(reaction);
        }

        setState(() {
          _allReactions = reactions;
          _reactionsByType = grouped;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeReactions = widget.reactionsSummary.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reactions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
          if (!_isLoading)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.blue.shade700,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                tabs: [
                  Tab(
                    child: Row(
                      children: [
                        const Text('All'),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_allReactions.length}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...activeReactions.map((entry) {
                    final type = entry.key;
                    final count = entry.value as int;
                    final emoji = _reactionEmojis[type] ?? '👍';

                    return Tab(
                      child: Row(
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // All reactions
                      _buildReactionsList(_allReactions),

                      // Individual reaction types
                      ...activeReactions.map((entry) {
                        final type = entry.key;
                        final reactions = _reactionsByType[type] ?? [];
                        return _buildReactionsList(reactions);
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionsList(List<dynamic> reactions) {
    if (reactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_emotions_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No reactions yet',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reactions.length,
      itemBuilder: (context, index) {
        final reaction = reactions[index];
        final user = reaction['user'] as Map<String, dynamic>?;
        final type = reaction['type'] as String;
        final createdAt = reaction['createdAt'] as String?;

        if (user == null) return const SizedBox.shrink();

        final userName = user['name'] ?? 'Unknown User';
        final userAvatar = user['avatar'] as String?;
        final emoji = _reactionEmojis[type] ?? '👍';

        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.blue.shade100,
                backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(
                        UrlUtils.getFullAvatarUrl(userAvatar),
                      )
                    : null,
                child: userAvatar == null || userAvatar.isEmpty
                    ? Text(
                        userName.isNotEmpty
                            ? userName
                                .split(' ')
                                .map((n) => n[0])
                                .take(2)
                                .join()
                                .toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            userName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: createdAt != null
              ? Text(
                  // Use TimeUtils for proper local time conversion
                  TimeUtils.formatMessageTimestamp(createdAt),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                )
              : null,
          onTap: () {
            final userId = user['_id'] as String?;
            if (userId != null && mounted) {
              Navigator.pop(context);
              // Use a post-frame callback to avoid BuildContext across async gap
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(userId: userId),
                    ),
                  );
                }
              });
            }
          },
        );
      },
    );
  }
}
