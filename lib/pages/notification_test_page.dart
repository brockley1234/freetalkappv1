import 'package:flutter/material.dart';
import '../services/global_notification_service.dart';

/// Test page to manually trigger and test global notifications
/// This helps verify that notifications are displaying correctly
class NotificationTestPage extends StatefulWidget {
  const NotificationTestPage({super.key});

  @override
  State<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends State<NotificationTestPage> {
  final _notificationService = GlobalNotificationService();
  String _lastTest = 'No test run yet';

  void _testMessageNotification() {
    setState(() => _lastTest = 'Testing message notification...');

    // Ensure service is initialized
    _notificationService.initialize();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('To test: Have another user send you a real message'),
        backgroundColor: Colors.blue,
      ),
    );

    setState(() => _lastTest = 'Ready for message notification test');
  }

  void _testCommentNotification() {
    setState(() => _lastTest = 'Testing comment notification...');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Check if comment notification appeared at the top!'),
        backgroundColor: Colors.blue,
      ),
    );

    setState(() => _lastTest = 'Comment notification triggered');
  }

  void _testPokeNotification() {
    setState(() => _lastTest = 'Testing poke notification...');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Check if poke notification appeared at the top!'),
        backgroundColor: Colors.blue,
      ),
    );

    setState(() => _lastTest = 'Poke notification triggered');
  }

  void _testOverlayDirectly() {
    setState(() => _lastTest = 'Testing overlay directly...');

    try {
      final navigatorState = _notificationService.navigatorKey.currentState;
      final context = _notificationService.navigatorKey.currentContext;

      debugPrint('Navigator State: $navigatorState');
      debugPrint('Navigator Context: $context');

      if (navigatorState == null || context == null) {
        setState(() => _lastTest = 'ERROR: Navigator not ready');
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('ERROR: Navigator not ready!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final overlayState = navigatorState.overlay;
      debugPrint('Overlay State: $overlayState');

      if (overlayState == null) {
        setState(() => _lastTest = 'ERROR: Overlay state is null');
        if (mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
              content: Text('ERROR: Overlay state not available!'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create a test overlay
      final overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'TEST OVERLAY - This should appear at the top!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );

      overlayState.insert(overlayEntry);

      // Remove after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        overlayEntry.remove();
      });

      setState(() => _lastTest = 'Direct overlay test: SUCCESS! ✅');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Direct overlay inserted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      setState(() => _lastTest = 'ERROR: $e');
      debugPrint('Error testing overlay: $e');
      debugPrint('Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ERROR: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _checkNotificationServiceStatus() {
    final navigatorState = _notificationService.navigatorKey.currentState;
    final navigatorContext = _notificationService.navigatorKey.currentContext;
    final scaffoldMessenger =
        _notificationService.scaffoldMessengerKey.currentState;

    final status = StringBuffer();
    status.writeln('Notification Service Status:');
    status.writeln(
      'Navigator State: ${navigatorState != null ? "✅ Ready" : "❌ Not ready"}',
    );
    status.writeln(
      'Navigator Context: ${navigatorContext != null ? "✅ Ready" : "❌ Not ready"}',
    );
    status.writeln(
      'ScaffoldMessenger: ${scaffoldMessenger != null ? "✅ Ready" : "❌ Not ready"}',
    );

    if (navigatorState != null) {
      final overlayState = navigatorState.overlay;
      status.writeln(
        'Overlay State: ${overlayState != null ? "✅ Ready" : "❌ Not ready"}',
      );
    }

    setState(() => _lastTest = status.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Service Status'),
        content: Text(status.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Test Global Notifications',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use these buttons to test if notifications are displaying correctly.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Last Test: $_lastTest',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTestButton(
            'Check Service Status',
            Icons.info_outline,
            Colors.blue,
            _checkNotificationServiceStatus,
          ),
          _buildTestButton(
            'Test Direct Overlay',
            Icons.layers,
            Colors.purple,
            _testOverlayDirectly,
          ),
          _buildTestButton(
            'Test Message Notification',
            Icons.message,
            Colors.green,
            _testMessageNotification,
          ),
          _buildTestButton(
            'Test Comment Notification',
            Icons.comment,
            Colors.orange,
            _testCommentNotification,
          ),
          _buildTestButton(
            'Test Poke Notification',
            Icons.pan_tool,
            Colors.pink,
            _testPokeNotification,
          ),
          const SizedBox(height: 24),
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 How to test:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Tap "Check Service Status" to verify everything is ready',
                  ),
                  Text(
                    '2. Tap "Test Direct Overlay" to verify overlay system works',
                  ),
                  Text('3. Try other notification types'),
                  Text(
                    '4. Look for notifications appearing at the top of the screen',
                  ),
                  SizedBox(height: 8),
                  Text(
                    'For real notifications: Have another user send you a message, comment, like, etc.',
                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }
}
