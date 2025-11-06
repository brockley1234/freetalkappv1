import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class for requesting permissions with proper user context and rationale
/// Complies with Apple App Store and Google Play Store guidelines
class PermissionHelper {
  /// Request camera permission with context explanation
  static Future<bool> requestCameraPermission(
    BuildContext context, {
    required String purpose,
  }) async {
    final status = await Permission.camera.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      // Show rationale dialog before requesting permission
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Camera Access Required',
        message: 'ReelChat needs camera access to $purpose.\n\n'
            'Camera access is only used when you actively use this feature. '
            'Your privacy is important to us.',
        icon: Icons.camera_alt,
      );

      if (!shouldRequest) return false;

      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Camera Permission Required',
        message: 'Camera access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Request microphone permission with context explanation
  static Future<bool> requestMicrophonePermission(
    BuildContext context, {
    required String purpose,
  }) async {
    final status = await Permission.microphone.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Microphone Access Required',
        message: 'ReelChat needs microphone access to $purpose.\n\n'
            'Microphone access is only active when you use voice features. '
            'Your recordings are never shared without your permission.',
        icon: Icons.mic,
      );

      if (!shouldRequest) return false;

      final result = await Permission.microphone.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Microphone Permission Required',
        message: 'Microphone access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Request photos permission with context explanation
  static Future<bool> requestPhotosPermission(
    BuildContext context, {
    required String purpose,
  }) async {
    final status = await Permission.photos.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Photo Library Access Required',
        message: 'ReelChat needs photo library access to $purpose.\n\n'
            'You control which photos and videos are shared. '
            'We never access your photo library without your action.',
        icon: Icons.photo_library,
      );

      if (!shouldRequest) return false;

      final result = await Permission.photos.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Photo Library Permission Required',
        message: 'Photo library access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await Permission.photos.request();
    return result.isGranted;
  }

  /// Request storage permission for Android (API < 33)
  static Future<bool> requestStoragePermission(
    BuildContext context, {
    required String purpose,
  }) async {
    final status = await Permission.storage.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Storage Access Required',
        message: 'ReelChat needs storage access to $purpose.\n\n'
            'This allows you to save and share media files.',
        icon: Icons.folder,
      );

      if (!shouldRequest) return false;

      final result = await Permission.storage.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Storage Permission Required',
        message: 'Storage access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await Permission.storage.request();
    return result.isGranted;
  }

  /// Request location permission with context explanation
  static Future<bool> requestLocationPermission(
    BuildContext context, {
    required String purpose,
    bool whenInUse = true,
  }) async {
    final permission =
        whenInUse ? Permission.locationWhenInUse : Permission.location;
    final status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Location Access Required',
        message: 'ReelChat needs location access to $purpose.\n\n'
            'Location is ${whenInUse ? "only accessed when you're using the app" : "accessed in the background"}. '
            'You can control location sharing in your privacy settings.',
        icon: Icons.location_on,
      );

      if (!shouldRequest) return false;

      final result = await permission.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Location Permission Required',
        message: 'Location access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await permission.request();
    return result.isGranted;
  }

  /// Request contacts permission with context explanation
  static Future<bool> requestContactsPermission(
    BuildContext context, {
    required String purpose,
  }) async {
    final status = await Permission.contacts.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      if (!context.mounted) return false;
      final shouldRequest = await _showPermissionRationale(
        context,
        title: 'Contacts Access Required',
        message: 'ReelChat needs contacts access to $purpose.\n\n'
            'Contact information is never stored on our servers without your explicit consent. '
            'You can skip this and find friends manually.',
        icon: Icons.contacts,
      );

      if (!shouldRequest) return false;

      final result = await Permission.contacts.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      await _showSettingsDialog(
        context,
        title: 'Contacts Permission Required',
        message: 'Contacts access has been permanently denied. '
            'Please enable it in Settings to $purpose.',
      );
      return false;
    }

    final result = await Permission.contacts.request();
    return result.isGranted;
  }

  /// Show permission rationale dialog
  static Future<bool> _showPermissionRationale(
    BuildContext context, {
    required String title,
    required String message,
    required IconData icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            message,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow Access'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show settings dialog for permanently denied permissions
  static Future<void> _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Request multiple permissions for video call (camera + microphone)
  static Future<bool> requestVideoCallPermissions(BuildContext context) async {
    final cameraGranted = await requestCameraPermission(
      context,
      purpose: 'enable video calling with your friends',
    );

    if (!cameraGranted) return false;
    if (!context.mounted) return false;

    final micGranted = await requestMicrophonePermission(
      context,
      purpose: 'enable audio in video calls',
    );

    return micGranted;
  }

  /// Request multiple permissions for voice call (microphone only)
  static Future<bool> requestVoiceCallPermissions(BuildContext context) async {
    return await requestMicrophonePermission(
      context,
      purpose: 'enable voice calling with your friends',
    );
  }

  /// Request multiple permissions for photo/video upload
  static Future<bool> requestMediaUploadPermissions(
      BuildContext context) async {
    // For Android 13+ (API 33+), use granular media permissions
    // For older versions, use storage permission
    return await requestPhotosPermission(
      context,
      purpose: 'select photos and videos to share',
    );
  }
}
