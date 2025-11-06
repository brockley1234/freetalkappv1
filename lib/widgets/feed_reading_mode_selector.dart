import 'package:flutter/material.dart';

/// Enum for different feed reading modes
enum FeedReadingMode {
  normal,    // Full cards with all features
  compact,   // Smaller cards, minimal spacing
  card,      // Pinterest-like grid layout
  list,      // Text-focused, minimal images
}

/// Widget to switch between different reading modes
class FeedReadingModeSelector extends StatefulWidget {
  final FeedReadingMode selectedMode;
  final ValueChanged<FeedReadingMode> onModeChanged;

  const FeedReadingModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
  });

  @override
  State<FeedReadingModeSelector> createState() =>
      _FeedReadingModeSelectorState();
}

class _FeedReadingModeSelectorState extends State<FeedReadingModeSelector>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildModeButton(
              icon: Icons.view_agenda,
              label: 'Normal',
              mode: FeedReadingMode.normal,
            ),
            const SizedBox(width: 8),
            _buildModeButton(
              icon: Icons.view_list,
              label: 'Compact',
              mode: FeedReadingMode.compact,
            ),
            const SizedBox(width: 8),
            _buildModeButton(
              icon: Icons.grid_view,
              label: 'Card',
              mode: FeedReadingMode.card,
            ),
            const SizedBox(width: 8),
            _buildModeButton(
              icon: Icons.view_stream,
              label: 'List',
              mode: FeedReadingMode.list,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required FeedReadingMode mode,
  }) {
    final isSelected = widget.selectedMode == mode;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onModeChanged(mode);
          _animationController.forward(from: 0.0);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [Colors.blue.shade400, Colors.purple.shade400],
                  )
                : null,
            color: isSelected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : Colors.grey.shade300,
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Configuration for different reading modes
class FeedDisplayConfig {
  final FeedReadingMode mode;
  final double cardHeight;
  final double horizontalPadding;
  final double verticalSpacing;
  final int gridCrossAxisCount;
  final bool showImages;
  final bool showAuthorInfo;
  final bool showReactions;

  const FeedDisplayConfig({
    required this.mode,
    required this.cardHeight,
    required this.horizontalPadding,
    required this.verticalSpacing,
    required this.gridCrossAxisCount,
    required this.showImages,
    required this.showAuthorInfo,
    required this.showReactions,
  });

  static FeedDisplayConfig forMode(FeedReadingMode mode) {
    switch (mode) {
      case FeedReadingMode.normal:
        return const FeedDisplayConfig(
          mode: FeedReadingMode.normal,
          cardHeight: 500,
          horizontalPadding: 16,
          verticalSpacing: 16,
          gridCrossAxisCount: 1,
          showImages: true,
          showAuthorInfo: true,
          showReactions: true,
        );
      case FeedReadingMode.compact:
        return const FeedDisplayConfig(
          mode: FeedReadingMode.compact,
          cardHeight: 300,
          horizontalPadding: 12,
          verticalSpacing: 8,
          gridCrossAxisCount: 1,
          showImages: true,
          showAuthorInfo: true,
          showReactions: true,
        );
      case FeedReadingMode.card:
        return const FeedDisplayConfig(
          mode: FeedReadingMode.card,
          cardHeight: 250,
          horizontalPadding: 8,
          verticalSpacing: 8,
          gridCrossAxisCount: 2,
          showImages: true,
          showAuthorInfo: false,
          showReactions: false,
        );
      case FeedReadingMode.list:
        return const FeedDisplayConfig(
          mode: FeedReadingMode.list,
          cardHeight: 150,
          horizontalPadding: 16,
          verticalSpacing: 8,
          gridCrossAxisCount: 1,
          showImages: false,
          showAuthorInfo: true,
          showReactions: true,
        );
    }
  }

  @override
  String toString() =>
      'FeedDisplayConfig(mode: $mode, cardHeight: $cardHeight)';
}
