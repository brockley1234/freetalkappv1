import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import 'user_profile_page.dart';
import 'premium_subscription_page.dart';

class ProfileVisitorsPage extends StatefulWidget {
  const ProfileVisitorsPage({super.key});

  @override
  State<ProfileVisitorsPage> createState() => _ProfileVisitorsPageState();
}

class _ProfileVisitorsPageState extends State<ProfileVisitorsPage> {
  final SocketService _socketService = SocketService();
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _requiresPremium = false;
  List<Map<String, dynamic>> _visitors = [];
  int _currentPage = 1;
  int _totalPages = 1;
  final ScrollController _scrollController = ScrollController();
  Function(dynamic)? _profileVisitedListener;

  @override
  void initState() {
    super.initState();
    _loadVisitors();
    _scrollController.addListener(_onScroll);
    _setupSocketListener();
  }

  void _setupSocketListener() {
    // Listen for real-time profile visits
    _profileVisitedListener = (data) {
      if (mounted && data != null) {
        debugPrint('👀 Real-time profile visit received: $data');

        final visitor = data['visitor'] as Map<String, dynamic>?;
        final visitCount = data['visitCount'] as int? ?? 1;
        final lastVisit = data['lastVisit'] as String?;

        if (visitor != null) {
          setState(() {
            // Check if visitor already exists in the list
            final existingIndex = _visitors.indexWhere(
              (v) => v['user']['_id'] == visitor['_id'],
            );

            if (existingIndex != -1) {
              // Update existing visitor
              _visitors[existingIndex] = {
                'user': visitor,
                'lastVisit': lastVisit,
                'visitCount': visitCount,
              };

              // Move to top of list (most recent)
              final updatedVisitor = _visitors.removeAt(existingIndex);
              _visitors.insert(0, updatedVisitor);
            } else {
              // Add new visitor at the top
              _visitors.insert(0, {
                'user': visitor,
                'lastVisit': lastVisit,
                'visitCount': visitCount,
              });
            }
          });

          debugPrint('👀 ✅ Visitor list updated in real-time');
        }
      }
    };

    _socketService.on('profile:visited', _profileVisitedListener!);
    debugPrint('👀 Socket listener set up for profile visits');
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_profileVisitedListener != null) {
      _socketService.off('profile:visited', _profileVisitedListener);
    }
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _currentPage < _totalPages) {
        _loadMoreVisitors();
      }
    }
  }

  Future<void> _loadVisitors() async {
    setState(() {
      _isLoading = true;
      _requiresPremium = false;
    });

    try {
      final result = await ApiService.getProfileVisitors(page: 1, limit: 20);

      if (mounted) {
        // Check if premium is required
        if (result['requiresPremium'] == true) {
          setState(() {
            _isLoading = false;
            _requiresPremium = true;
          });
          return;
        }

        if (result['success'] == true) {
          setState(() {
            _visitors = List<Map<String, dynamic>>.from(
              result['data']['visitors'] ?? [],
            );
            _currentPage = result['data']['pagination']['page'];
            _totalPages = result['data']['pagination']['pages'];
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to load visitors'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load visitors: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreVisitors() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final result = await ApiService.getProfileVisitors(
        page: _currentPage + 1,
        limit: 20,
      );

      if (mounted && result['success'] == true) {
        setState(() {
          _visitors.addAll(
            List<Map<String, dynamic>>.from(result['data']['visitors'] ?? []),
          );
          _currentPage = result['data']['pagination']['page'];
          _totalPages = result['data']['pagination']['pages'];
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile Visitors',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading visitors...',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _requiresPremium
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          size: 50,
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Premium Feature',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Buy Premium to see\nwho visits your profile',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const PremiumSubscriptionPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Upgrade to Premium',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _visitors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.visibility_off_outlined,
                              size: 50,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No visitors yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'People who view your profile will appear here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadVisitors,
                      color: Theme.of(context).colorScheme.primary,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _visitors.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _visitors.length) {
                            return Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Loading more...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final visitor = _visitors[index];
                          final user = visitor['user'] as Map<String, dynamic>;
                          final lastVisit = visitor['lastVisit'] as String?;
                          final visitCount = visitor['visitCount'] as int? ?? 1;

                          return _buildVisitorTile(user, lastVisit, visitCount);
                        },
                      ),
                    ),
    );
  }

  Widget _buildVisitorTile(
    Map<String, dynamic> user,
    String? lastVisit,
    int visitCount,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(userId: user['_id']),
              ),
            );
          },
          child: CircleAvatar(
            radius: 30,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            backgroundImage: user['avatar'] != null
                ? UrlUtils.getAvatarImageProvider(user['avatar'])
                : null,
            child: user['avatar'] == null
                ? Text(
                    user['name']?[0]?.toUpperCase() ?? '?',
                    style: TextStyle(
                      fontSize: 22,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (visitCount > 1) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$visitCount visits',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                user['bio'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    lastVisit != null
                        ? 'Visited ${TimeUtils.formatMessageTimestamp(lastVisit)}'
                        : 'Recently visited',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfilePage(userId: user['_id']),
              ),
            );
          },
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: user['_id']),
            ),
          );
        },
      ),
    );
  }
}
