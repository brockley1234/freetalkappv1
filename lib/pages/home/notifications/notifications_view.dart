import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../widgets/notification_card.dart';
import '../../../utils/responsive_dimensions.dart';

/// Notifications view displaying user notifications
class NotificationsView extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final Function(String userId) onUserTap;
  final Function(String postId)? onPostTap;

  const NotificationsView({
    super.key,
    required this.currentUser,
    required this.onUserTap,
    this.onPostTap,
  });

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView>
    with AutomaticKeepAliveClientMixin {
  List<dynamic> _notifications = [];
  bool _isLoading = false;
  bool _hasError = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getNotifications();
      if (result['success'] == true && mounted) {
        setState(() {
          _notifications = result['data'] ?? [];
        });

        // Mark notifications as read
        _markNotificationsAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      // Mark all notifications as read
      await ApiService.markAllNotificationsAsRead();
    } catch (e) {
      // Fail silently - not critical
    }
  }

  Future<void> _refresh() async {
    await _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      onRefresh: _refresh,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _notifications.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load notifications',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll notify you when something happens',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(ResponsiveDimensions.getHorizontalPadding(context)),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return NotificationCard(
          notificationData: notification,
          onTap: () => _handleNotificationTap(notification),
        );
      },
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final type = notification['type'];
    final relatedUserId = notification['relatedUser']?['_id'];
    final postId = notification['post']?['_id'];

    switch (type) {
      case 'follow':
      case 'poke':
      case 'profile_visit':
        if (relatedUserId != null) {
          widget.onUserTap(relatedUserId);
        }
        break;
      case 'like':
      case 'comment':
      case 'share':
      case 'mention':
        if (postId != null && widget.onPostTap != null) {
          widget.onPostTap!(postId);
        }
        break;
      default:
        // Handle other notification types
        break;
    }
  }
}

