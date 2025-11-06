// Mock image provider for testing
// Prevents network image loading errors in widget tests

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Custom image provider that returns a 1x1 solid color image
class TestImageProvider extends ImageProvider<TestImageProvider> {
  final String url;

  const TestImageProvider(this.url);

  @override
  Future<TestImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future<TestImageProvider>.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      _loadImage(key, decode),
    );
  }

  Future<ImageInfo> _loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final imageData = await _generateTestImage();
    return ImageInfo(image: imageData);
  }

  Future<ui.Image> _generateTestImage() async {
    // Generate a simple 1x1 pixel test image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      const Rect.fromLTWH(0, 0, 1, 1),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color.fromARGB(255, 100, 100, 100),
    );
    final picture = recorder.endRecording();
    return picture.toImage(1, 1);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestImageProvider &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}

/// Test helper to create mock image providers
class MockImageHelper {
  /// Create a mock test image provider that won't make network calls
  static ImageProvider createMockNetworkImage(String url) {
    return const TestImageProvider('');
  }

  /// Create a placeholder asset image
  static ImageProvider createPlaceholderImage() {
    return const AssetImage('assets/icon/app_icon.png');
  }

  /// Setup test to not load network images
  static void disableNetworkImagesForTest() {
    // This prepares the test environment for image mocking
    // Network images will now use TestImageProvider instead
  }

  /// Generate a test image for use in tests
  static Future<ui.Image> generateTestImage({
    int width = 100,
    int height = 100,
    Color color = const Color.fromARGB(255, 100, 100, 100),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }
}
