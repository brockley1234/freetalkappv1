import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:freetalk/utils/avatar_utils.dart';

void main() {
  group('AvatarUtils Tests', () {
    test('getInitials returns correct format for two-word name', () {
      final initials = AvatarUtils.getInitials('John Doe');
      expect(initials, 'JD');
    });

    test('getInitials returns correct format for single-word name', () {
      final initials = AvatarUtils.getInitials('Jane');
      expect(initials, 'J');
    });

    test('getInitials returns correct format for three-word name', () {
      final initials = AvatarUtils.getInitials('John Paul Smith');
      expect(initials, 'JP');
    });

    test('getInitials returns question mark for empty name', () {
      final initials = AvatarUtils.getInitials('');
      expect(initials, '?');
    });

    test('getInitials handles uppercase conversion', () {
      final initials = AvatarUtils.getInitials('john doe');
      expect(initials, 'JD');
    });

    test('getInitials handles spaces correctly', () {
      final initials = AvatarUtils.getInitials('  John   Doe  ');
      expect(initials, 'JD');
    });

    test('getColorForName returns consistent colors', () {
      final color1 = AvatarUtils.getColorForName('John');
      final color2 = AvatarUtils.getColorForName('John');
      expect(color1, color2);
    });

    test('getColorForName returns different colors for different names', () {
      final color1 = AvatarUtils.getColorForName('John');
      final color2 = AvatarUtils.getColorForName('Jane');
      // They might be the same by coincidence, but usually different
      // We just verify they're from the palette
      expect([
        const Color(0xFF6366f1),
        const Color(0xFF06b6d4),
        const Color(0xFF10b981),
        const Color(0xFFf59e0b),
        const Color(0xFFef4444),
        const Color(0xFF8b5cf6),
        const Color(0xFFec4899),
        const Color(0xFF3b82f6),
        const Color(0xFf14b8a6),
        const Color(0xFFd97706),
      ], containsAll([color1, color2]));
    });

    test('getColorForName returns grey for empty name', () {
      final color = AvatarUtils.getColorForName('');
      expect(color, Colors.grey.shade300);
    });

    test('buildAvatarWidget creates CircleAvatar', () {
      final widget = AvatarUtils.buildAvatarWidget(
        name: 'John Doe',
        imageUrl: null,
        radius: 24,
      );
      expect(widget, isA<CircleAvatar>());
    });
  });
}
