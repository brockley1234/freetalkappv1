import 'package:flutter/material.dart';

class ReactionPicker extends StatefulWidget {
  final Function(String) onReactionSelected;
  final String? currentReaction;

  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
    this.currentReaction,
  });

  @override
  State<ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<ReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> reactions = [
    {'type': 'like', 'emoji': '👍', 'label': 'Like', 'color': Colors.blue},
    {
      'type': 'celebrate',
      'emoji': '🎉',
      'label': 'Celebrate',
      'color': Colors.purple,
    },
    {
      'type': 'insightful',
      'emoji': '💡',
      'label': 'Insightful',
      'color': Colors.amber.shade800,
    },
    {'type': 'funny', 'emoji': '😂', 'label': 'Funny', 'color': Colors.orange},
    {
      'type': 'mindblown',
      'emoji': '🤯',
      'label': 'Mindblown',
      'color': Colors.deepPurple,
    },
    {
      'type': 'support',
      'emoji': '🤝',
      'label': 'Support',
      'color': Colors.green,
    },
  ];

  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: reactions.asMap().entries.map((entry) {
                final index = entry.key;
                final reaction = entry.value;
                final isHovered = _hoveredIndex == index;
                final isCurrent = widget.currentReaction == reaction['type'];

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = index),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: GestureDetector(
                    onTap: () {
                      widget.onReactionSelected(reaction['type']);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      transform: Matrix4.identity()
                        ..scaleByDouble(
                          isHovered ? 1.4 : (isCurrent ? 1.15 : 1.0),
                          isHovered ? 1.4 : (isCurrent ? 1.15 : 1.0),
                          1.0,
                          1.0,
                        )
                        ..translateByDouble(
                          0.0,
                          isHovered ? -10.0 : 0.0,
                          0.0,
                          1.0,
                        ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Show label on hover
                          if (isHovered)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: (reaction['color'] as Color).withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                reaction['label'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: reaction['color'],
                                ),
                              ),
                            ),

                          // Emoji
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCurrent
                                  ? (reaction['color'] as Color).withValues(
                                      alpha: 0.1,
                                    )
                                  : Colors.transparent,
                              border: isCurrent
                                  ? Border.all(
                                      color: reaction['color'],
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                reaction['emoji'],
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// Overlay helper to show reaction picker
class ReactionPickerOverlay {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    String? postId,
    required Function(String) onReactionSelected,
    String? currentReaction,
  }) {
    // Remove existing overlay if any
    hide();

    // Find the react button by searching through the widget tree
    // We'll use a simpler approach - show at cursor position if available
    // or show at bottom center of screen

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            // Transparent barrier to detect outside taps
            Positioned.fill(
              child: GestureDetector(
                onTap: hide,
                child: Container(color: Colors.transparent),
              ),
            ),
            // Reaction picker - positioned using LayoutBuilder to find button
            _ReactionPickerPositioned(
              postId: postId,
              onReactionSelected: (reactionType) {
                hide();
                onReactionSelected(reactionType);
              },
              currentReaction: currentReaction,
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

// Widget that positions itself above the react button
class _ReactionPickerPositioned extends StatefulWidget {
  final String? postId;
  final Function(String) onReactionSelected;
  final String? currentReaction;

  const _ReactionPickerPositioned({
    this.postId,
    required this.onReactionSelected,
    this.currentReaction,
  });

  @override
  State<_ReactionPickerPositioned> createState() =>
      _ReactionPickerPositionedState();
}

class _ReactionPickerPositionedState extends State<_ReactionPickerPositioned> {
  Offset? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculatePosition();
    });
  }

  void _calculatePosition() {
    // Try to find the button position using the context
    // For now, we'll position it at a reasonable default location
    // In the center-bottom area where reaction buttons typically are

    final Size screenSize = MediaQuery.of(context).size;

    // Position in the lower third of the screen, towards the left
    // where the react button typically is
    setState(() {
      _position = Offset(
        20, // 20px from left edge
        screenSize.height * 0.7, // 70% down the screen
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_position == null) {
      return const SizedBox.shrink();
    }

    final Size screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position!.dx,
      bottom:
          screenSize.height - _position!.dy + 10, // Position above the button
      child: ReactionPicker(
        onReactionSelected: widget.onReactionSelected,
        currentReaction: widget.currentReaction,
      ),
    );
  }
}
