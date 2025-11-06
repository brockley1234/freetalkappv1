import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'services/api_service.dart';
import 'services/socket_service.dart';
import 'services/global_notification_service.dart';
import 'services/realtime_update_service.dart';
import 'pages/loginpage.dart';
import 'pages/homepage.dart';
import 'pages/post_detail_page.dart';
import 'pages/recover_pin_page.dart';
import 'utils/app_logger.dart';

class AuthWrapper extends StatefulWidget {
  final String? initialDeepLink;

  const AuthWrapper({super.key, this.initialDeepLink});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  final _logger = AppLogger();
  bool _hasCheckedAuth = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check auth status when dependencies change (e.g., after navigation)
    // But only if we've already checked once before
    if (_hasCheckedAuth && !_isLoading) {
      _checkAuthStatus();
    }
  }

  Future<void> _checkAuthStatus() async {
    try {
      _logger.info('Checking authentication status...');

      // Mark that we've checked auth at least once
      _hasCheckedAuth = true;

      // Check if user is logged in
      final isLoggedIn = await ApiService.isLoggedIn();

      if (isLoggedIn) {
        // Verify token is still valid by making an API call
        final result = await ApiService.getCurrentUser();

        if (result['success'] == true) {
          // Check if user is banned or suspended
          final userData = result['data']?['user'];
          final isBanned = userData?['isBanned'] ?? false;
          final isSuspended = userData?['isSuspended'] ?? false;

          if (isBanned) {
            _logger.warning('🚫 User is banned, logging out...');
            await ApiService.clearTokens();

            if (mounted) {
              // Show banned message
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.block, color: Colors.red, size: 32),
                      SizedBox(width: 12),
                      Text('Account Banned'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData?['suspensionReason'] ??
                            'Your account has been permanently banned by an administrator.',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please contact support if you believe this is an error.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }

            setState(() {
              _isAuthenticated = false;
              _isLoading = false;
            });
            return;
          }

          if (isSuspended) {
            _logger.warning('⚠️ User is suspended, logging out...');
            await ApiService.clearTokens();

            if (mounted) {
              // Show suspended message
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 32),
                      SizedBox(width: 12),
                      Text('Account Suspended'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userData?['suspensionReason'] ??
                            'Your account has been suspended by an administrator.',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please contact support if you believe this is an error.',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }

            setState(() {
              _isAuthenticated = false;
              _isLoading = false;
            });
            return;
          }

          try {
            // Refresh token before connecting to Socket.IO
            _logger.info('🔄 Refreshing token before Socket connection...');
            final tokenRefreshed = await ApiService.refreshToken();
            if (tokenRefreshed != true) {
              _logger.warning('⚠️ Token refresh failed, but continuing with existing token');
            } else {
              _logger.info('✅ Token refreshed successfully');
            }

            // Initialize Socket.IO connection (non-blocking)
            _logger.info('🔌 Initializing Socket.IO connection...');
            SocketService().connect().then((_) {
              _logger.info('✅ Socket connected successfully');
            }).catchError((error) {
              _logger.warning('⚠️ Socket connection error: $error');
            });

            // Initialize services immediately (they will work once socket connects)
            // Don't wait for socket - it will connect in the background
            _logger.info('🚀 Initializing services...');
            GlobalNotificationService().initialize();
            RealtimeUpdateService().initialize();
            _logger.info('✅ All services initialized successfully');
          } catch (e, st) {
            _logger.error('Error initializing services',
                error: e, stackTrace: st);
            // Don't block login on socket errors
          }
        }

        setState(() {
          _isAuthenticated = result['success'] == true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      _logger.error('Auth check failed', error: e, stackTrace: st);

      // Token is invalid or expired
      await ApiService.clearTokens();
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // Note: Don't disconnect socket here as AuthWrapper rebuilds during normal app lifecycle
    // Socket will disconnect when user logs out via logout action
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 200,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Check for deep links that don't require authentication FIRST (e.g., PIN reset)
    if (widget.initialDeepLink != null && widget.initialDeepLink!.isNotEmpty) {
      final uri = Uri.parse(widget.initialDeepLink!);
      _logger.debug('🔗 AuthWrapper: handling deep link: ${uri.path}');

      // Handle PIN reset link FIRST (works even when not authenticated)
      if (uri.path == '/reset-pin' || uri.pathSegments.contains('reset-pin')) {
        final token = uri.queryParameters['token'];
        _logger.debug('🔐 AuthWrapper: navigating to PIN reset with token');
        return RecoverPinPage(
          method: 'email',
          initialToken: token,
        );
      }
    }

    // If not authenticated, show login page (for other routes)
    if (!_isAuthenticated) {
      return const LoginPage();
    }

    // If authenticated, check for other deep links
    if (widget.initialDeepLink != null && widget.initialDeepLink!.isNotEmpty) {
      final uri = Uri.parse(widget.initialDeepLink!);

      // Check if it's a post detail link (requires authentication)
      if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'post') {
        final postId = uri.pathSegments[1];
        _logger.debug('📄 AuthWrapper: navigating to post $postId');
        return PostDetailPage(postId: postId);
      }
    }

    // Otherwise show home page
    return const HomePage();
  }
}
