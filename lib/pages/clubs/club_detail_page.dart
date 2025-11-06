import 'package:flutter/material.dart';
import '../../services/club_service.dart';
import '../../utils/app_logger.dart';

/// Club Detail Page - View and interact with a specific club
/// 
/// Features:
/// - View club information
/// - Join/leave club
/// - View members (admins, moderators, regular members)
/// - Admin: Approve/deny join requests
/// - Admin: Edit club details
/// - Admin: Delete club
/// - Smooth animations and better UI
class ClubDetailPage extends StatefulWidget {
  final String clubId;
  
  const ClubDetailPage({super.key, required this.clubId});

  @override
  State<ClubDetailPage> createState() => _ClubDetailPageState();
}

class _ClubDetailPageState extends State<ClubDetailPage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _club;
  Map<String, dynamic>? _members;
  late TabController _tabController;

  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;
  int _postsPage = 1;
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClub();
    _loadMembers();
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadClub() async {
    setState(() { _loading = true; _error = null; });
    
    try {
      final res = await ClubService.getClub(widget.clubId);
      
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _club = Map<String, dynamic>.from(res['data']['club'] ?? {});
            _loading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = res['message'] ?? 'Failed to load club';
            _loading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Failed to load club', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    try {
      final res = await ClubService.listMembers(widget.clubId);
      
      if (res['success'] == true && mounted) {
        setState(() {
          _members = Map<String, dynamic>.from(res['data'] ?? {});
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load members', error: e);
    }
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_loadingPosts) return;
    
    if (refresh) {
      setState(() {
        _postsPage = 1;
        _hasMorePosts = true;
        _posts = [];
      });
    }
    
    if (!_hasMorePosts && !refresh) return;
    
    setState(() { _loadingPosts = true; });
    
    try {
      final res = await ClubService.listPosts(widget.clubId, page: _postsPage);
      
      if (res['success'] == true && mounted) {
        final data = res['data'] as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        
        setState(() {
          if (refresh) {
            _posts = items;
          } else {
            _posts.addAll(items);
          }
          _hasMorePosts = data['hasMore'] ?? false;
          _postsPage++;
          _loadingPosts = false;
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load posts', error: e);
      if (mounted) {
        setState(() { _loadingPosts = false; });
      }
    }
  }

  Future<void> _joinClub() async {
    try {
      final res = await ClubService.joinClub(widget.clubId);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? (res['message'] ?? 'Joined club') : (res['message'] ?? 'Failed to join')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        await _loadClub();
        await _loadMembers();
      }
    } catch (e) {
      AppLogger.e('Failed to join club', error: e);
    }
  }

  Future<void> _leaveClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red),
            SizedBox(width: 8),
            Text('Leave Club'),
          ],
        ),
        content: const Text('Are you sure you want to leave this club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ClubService.leaveClub(widget.clubId);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? 'Left club' : (res['message'] ?? 'Failed to leave')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.orange : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.e('Failed to leave club', error: e);
    }
  }

  Future<void> _approveRequest(String userId, String userName) async {
    try {
      final res = await ClubService.approveRequest(widget.clubId, userId);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? 'Approved $userName' : (res['message'] ?? 'Failed')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        await _loadClub();
        await _loadMembers();
      }
    } catch (e) {
      AppLogger.e('Failed to approve request', error: e);
    }
  }

  Future<void> _denyRequest(String userId, String userName) async {
    try {
      final res = await ClubService.denyRequest(widget.clubId, userId);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? 'Denied $userName' : (res['message'] ?? 'Failed')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.orange : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        await _loadClub();
        await _loadMembers();
      }
    } catch (e) {
      AppLogger.e('Failed to deny request', error: e);
    }
  }

  Future<void> _inviteMembers() async {
    // In a real app, this would show a user search/selection dialog
    // For now, we'll show a simple text input for user IDs
    final userIdController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add),
            SizedBox(width: 8),
            Text('Invite Members'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter user IDs to invite (comma-separated):'),
              const SizedBox(height: 12),
              TextField(
                controller: userIdController,
                decoration: const InputDecoration(
                  labelText: 'User IDs',
                  hintText: 'e.g., 123abc, 456def',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                'Note: In the full app, this would be a user search interface.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
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
            onPressed: () => Navigator.pop(context, userIdController.text),
            icon: const Icon(Icons.send),
            label: const Text('Send Invitations'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        // Parse user IDs
        final userIds = result.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        
        if (userIds.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter valid user IDs'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final res = await ClubService.inviteUsers(widget.clubId, userIds);
        final ok = res['success'] == true;
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(ok ? (res['message'] ?? 'Invitations sent!') : (res['message'] ?? 'Failed to send invitations')),
                ),
              ],
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        AppLogger.e('Failed to invite members', error: e);
      }
    }
  }

  Future<void> _deleteClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Club'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this club? This action cannot be undone and will remove all members and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await ClubService.deleteClub(widget.clubId);
      final ok = res['success'] == true;
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(ok ? 'Club deleted' : (res['message'] ?? 'Failed to delete')),
              ),
            ],
          ),
          backgroundColor: ok ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      
      if (ok) {
        Navigator.pop(context);
      }
    } catch (e) {
      AppLogger.e('Failed to delete club', error: e);
    }
  }

  Future<void> _editClub() async {
    if (_club == null) return;

    final nameController = TextEditingController(text: _club!['name']);
    final descriptionController = TextEditingController(text: _club!['description'] ?? '');
    final categoryController = TextEditingController(text: _club!['category'] ?? '');
    String privacy = _club!['privacy'] ?? 'public';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit),
              SizedBox(width: 8),
              Text('Edit Club'),
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
                    hintText: 'Enter club name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  maxLength: 120,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Tell us about your club',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 3,
                  maxLength: 1000,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'e.g., Sports, Music, Gaming',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  maxLength: 50,
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
                      'description': descriptionController.text.trim(),
                      'category': categoryController.text.trim(),
                      'privacy': privacy,
                    },
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        final res = await ClubService.updateClub(
          widget.clubId,
          name: result['name'] as String,
          description: result['description'] as String,
          category: result['category'] as String,
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
                  child: Text(ok ? 'Club updated successfully!' : (res['message'] ?? 'Failed to update club')),
                ),
              ],
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        if (ok) {
          _loadClub();
        }
      } catch (e) {
        AppLogger.e('Failed to update club', error: e);
      }
    }
  }

  Future<void> _createPost() async {
    final contentController = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.post_add),
            SizedBox(width: 8),
            Text('Create Post'),
          ],
        ),
        content: SingleChildScrollView(
          child: TextField(
            controller: contentController,
            decoration: const InputDecoration(
              labelText: 'What\'s on your mind?',
              hintText: 'Share something with the club...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            maxLength: 5000,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, contentController.text),
            icon: const Icon(Icons.send),
            label: const Text('Post'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      try {
        final res = await ClubService.createPost(
          widget.clubId,
          content: result.trim(),
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
                  child: Text(ok ? 'Post created!' : (res['message'] ?? 'Failed to create post')),
                ),
              ],
            ),
            backgroundColor: ok ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        
        if (ok) {
          await _loadPosts(refresh: true);
        }
      } catch (e) {
        AppLogger.e('Failed to create post', error: e);
      }
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Post'),
          ],
        ),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ClubService.deletePost(widget.clubId, postId);
        final ok = res['success'] == true;
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Post deleted' : (res['message'] ?? 'Failed')),
            backgroundColor: ok ? Colors.green : Colors.red,
          ),
        );
        
        if (ok) {
          await _loadPosts(refresh: true);
        }
      } catch (e) {
        AppLogger.e('Failed to delete post', error: e);
      }
    }
  }

  Widget _buildPostsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMember = _club?['isMember'] == true;

    return Column(
      children: [
        // Create post button
        if (isMember)
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
            child: FilledButton.icon(
              onPressed: _createPost,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        
        // Posts list
        Expanded(
          child: _posts.isEmpty && !_loadingPosts
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.forum_outlined, size: 64, color: colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (isMember) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to post!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _posts.length + (_loadingPosts ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _posts.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final post = _posts[index];
                    final author = post['author'] as Map<String, dynamic>?;
                    final isAuthor = author?['_id'] == _club?['createdBy'];
                    final canDelete = isAuthor || _club?['isAdmin'] == true || _club?['isModerator'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Author header
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: Text(
                                    author?['name']?.toString()[0].toUpperCase() ?? '?',
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        author?['name'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _formatDate(post['createdAt']),
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canDelete)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deletePost(post['_id']),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Content
                            Text(post['content'] ?? ''),
                            
                            // Images
                            if (post['images'] != null && (post['images'] as List).isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: (post['images'] as List).map((img) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      color: colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.image),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            
                            const SizedBox(height: 12),
                            
                            // Actions
                            Row(
                              children: [
                                Icon(Icons.favorite_border, size: 20, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  '${post['reactionsCount'] ?? 0}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.comment_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  '${(post['comments'] as List?)?.length ?? 0}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return '';
      final dateTime = date is DateTime ? date : DateTime.parse(date.toString());
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      
      if (diff.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadClub,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadClub();
                    await _loadMembers();
                    await _loadPosts(refresh: true);
                  },
                  child: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverAppBar(
                        expandedHeight: 220,
                        pinned: true,
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            _club?['name'] ?? 'Club',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primaryContainer,
                                      colorScheme.secondaryContainer,
                                      colorScheme.tertiaryContainer,
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Hero(
                                  tag: 'club-avatar-${widget.clubId}',
                                  child: CircleAvatar(
                                    radius: 56,
                                    backgroundColor: colorScheme.surface,
                                    child: Icon(
                                      Icons.group,
                                      size: 56,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              if (_club?['isFeatured'] == true)
                                Positioned(
                                  top: 80,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade700,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star, size: 16, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Featured',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          if (_club?['isAdmin'] == true || _club?['isModerator'] == true)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editClub();
                                } else if (value == 'delete') {
                                  _deleteClub();
                                } else if (value == 'invite') {
                                  _inviteMembers();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'invite',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_add),
                                      SizedBox(width: 8),
                                      Text('Invite Members'),
                                    ],
                                  ),
                                ),
                                if (_club?['isAdmin'] == true)
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit),
                                        SizedBox(width: 8),
                                        Text('Edit Club'),
                                      ],
                                    ),
                                  ),
                                if (_club?['isAdmin'] == true)
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete Club', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverTabBarDelegate(
                          TabBar(
                            controller: _tabController,
                            tabs: const [
                              Tab(text: 'Posts', icon: Icon(Icons.forum)),
                              Tab(text: 'About', icon: Icon(Icons.info_outline)),
                              Tab(text: 'Members', icon: Icon(Icons.people)),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPostsTab(),
                        _buildAboutTab(),
                        _buildMembersTab(),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: _club != null ? _buildBottomActions() : null,
    );
  }

  Widget _buildAboutTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      Icons.people,
                      'Members',
                      '${_club?['membersCount'] ?? 0}',
                      colorScheme,
                    ),
                  ),
                  Container(width: 1, height: 50, color: colorScheme.outlineVariant),
                  Expanded(
                    child: _buildStatItem(
                      Icons.admin_panel_settings,
                      'Admins',
                      '${_club?['adminsCount'] ?? 0}',
                      colorScheme,
                    ),
                  ),
                  Container(width: 1, height: 50, color: colorScheme.outlineVariant),
                  Expanded(
                    child: _buildStatItem(
                      Icons.shield,
                      'Moderators',
                      '${_club?['moderatorsCount'] ?? 0}',
                      colorScheme,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Description
          if ((_club?['description'] ?? '').toString().isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.description, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Description',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _club?['description'].toString() ?? '',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Details
          Row(
            children: [
              Icon(Icons.info, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Details',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                if ((_club?['category'] ?? '').toString().isNotEmpty)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.category, color: colorScheme.primary),
                    ),
                    title: const Text('Category'),
                    trailing: Chip(
                      label: Text(_club?['category'].toString() ?? ''),
                      backgroundColor: colorScheme.tertiaryContainer,
                    ),
                  ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _club?['privacy'] == 'private' ? Icons.lock : Icons.public,
                      color: colorScheme.primary,
                    ),
                  ),
                  title: const Text('Privacy'),
                  trailing: Chip(
                    label: Text(_club?['privacy'] == 'private' ? 'Private' : 'Public'),
                    backgroundColor: _club?['privacy'] == 'private'
                        ? colorScheme.errorContainer
                        : colorScheme.secondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          
          // Tags
          if (_club?['tags'] != null && (_club?['tags'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.local_offer, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Tags',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_club?['tags'] as List).map((tag) {
                return Chip(
                  label: Text(tag.toString()),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide(color: colorScheme.outline),
                );
              }).toList(),
            ),
          ],
          
          // Rules
          if (_club?['rules'] != null && (_club?['rules'] as List).isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.rule, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Club Rules',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: (_club?['rules'] as List).asMap().entries.map((entry) {
                  final index = entry.key;
                  final rule = entry.value;
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(rule.toString()),
                  );
                }).toList(),
              ),
            ),
          ],
          
          const SizedBox(height: 100), // Space for bottom actions
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (_members == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final admins = List<Map<String, dynamic>>.from(_members?['admins'] ?? []);
    final moderators = List<Map<String, dynamic>>.from(_members?['moderators'] ?? []);
    final members = List<Map<String, dynamic>>.from(_members?['members'] ?? []);
    final pendingRequests = List<Map<String, dynamic>>.from(_members?['pendingRequests'] ?? []);
    
    final isAdminOrMod = _club?['isAdmin'] == true || _club?['isModerator'] == true;
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending Requests (admins/moderators only)
        if (isAdminOrMod && pendingRequests.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.pending, color: Colors.orange.shade700),
              ),
              const SizedBox(width: 8),
              Text(
                'Pending Requests (${pendingRequests.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: pendingRequests.asMap().entries.map((entry) {
                final user = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.secondaryContainer,
                        child: Text(
                          user['name']?.toString()[0].toUpperCase() ?? '?',
                          style: TextStyle(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: user['username'] != null ? Text('@${user['username']}') : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filled(
                            icon: const Icon(Icons.check, size: 20),
                            tooltip: 'Approve',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _approveRequest(user['_id'], user['name'] ?? 'User'),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Deny',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _denyRequest(user['_id'], user['name'] ?? 'User'),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Admins
        if (admins.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.admin_panel_settings, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'Admins (${admins.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: admins.asMap().entries.map((entry) {
                final user = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.admin_panel_settings, color: colorScheme.onPrimaryContainer),
                      ),
                      title: Text(user['name'] ?? 'Unknown'),
                      subtitle: user['username'] != null ? Text('@${user['username']}') : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Moderators
        if (moderators.isNotEmpty) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield, color: colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 8),
              Text(
                'Moderators (${moderators.length})',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: moderators.asMap().entries.map((entry) {
                final user = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.secondaryContainer,
                        child: Icon(Icons.shield, color: colorScheme.onSecondaryContainer),
                      ),
                      title: Text(user['name'] ?? 'Unknown'),
                      subtitle: user['username'] != null ? Text('@${user['username']}') : null,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Moderator',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ],
        
        // Members
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.people, color: colorScheme.onTertiaryContainer),
            ),
            const SizedBox(width: 8),
            Text(
              'Members (${members.length})',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (members.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No members yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: members.asMap().entries.map((entry) {
                final user = entry.value;
                return Column(
                  children: [
                    if (entry.key > 0) const Divider(height: 1),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.tertiaryContainer,
                        child: Text(
                          user['name']?.toString()[0].toUpperCase() ?? '?',
                          style: TextStyle(
                            color: colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(user['name'] ?? 'Unknown'),
                      subtitle: user['username'] != null ? Text('@${user['username']}') : null,
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        
        const SizedBox(height: 100), // Space for bottom actions
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(icon, size: 32, color: colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomActions() {
    final colorScheme = Theme.of(context).colorScheme;
    final isMember = _club?['isMember'] == true;
    final hasPendingRequest = _club?['hasPendingRequest'] == true;
    
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: isMember
            ? FilledButton.tonalIcon(
                onPressed: _leaveClub,
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave Club'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                  minimumSize: const Size(double.infinity, 52),
                ),
              )
            : hasPendingRequest
                ? FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.pending),
                    label: const Text('Request Pending'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _joinClub,
                    icon: const Icon(Icons.group_add),
                    label: Text(_club?['privacy'] == 'private' ? 'Request to Join' : 'Join Club'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
