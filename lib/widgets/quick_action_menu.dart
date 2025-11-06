import 'package:flutter/material.dart';

/// Quick action model for FAB menu
class QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });
}

/// Animated quick action menu/FAB
class QuickActionMenu extends StatefulWidget {
  final List<QuickAction> actions;
  final VoidCallback? onPrimaryAction;
  final bool isExpanded;

  const QuickActionMenu({
    super.key,
    required this.actions,
    this.onPrimaryAction,
    this.isExpanded = false,
  });

  @override
  State<QuickActionMenu> createState() => _QuickActionMenuState();
}

class _QuickActionMenuState extends State<QuickActionMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 0.45).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Semi-transparent background when expanded
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
              ),
            ),
          ),

        // Floating action buttons for each action
        ...List.generate(
          widget.actions.length,
          (index) => _buildActionButton(index),
        ),

        // Primary FAB (Create Post)
        Positioned(
          bottom: 0,
          right: 0,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _toggleMenu();
                  if (!_isExpanded && widget.onPrimaryAction != null) {
                    widget.onPrimaryAction!();
                  }
                },
                borderRadius: BorderRadius.circular(56),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade400,
                        Colors.purple.shade400,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: RotationTransition(
                    turns: _rotateAnimation,
                    child: Icon(
                      _isExpanded ? Icons.close : Icons.add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(int index) {
    final action = widget.actions[index];
    const double distance = 100.0;

    return Positioned(
      bottom: distance * (1 - (index * 0.2).clamp(0, 1)),
      right: distance * (index * 0.1).clamp(0, 1),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              index * 0.1,
              0.6 + (index * 0.1),
              curve: Curves.elasticOut,
            ),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              action.onTap();
              _toggleMenu();
            },
            borderRadius: BorderRadius.circular(48),
            child: Tooltip(
              message: action.tooltip ?? action.label,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: action.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  action.icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal bottom sheet for quick actions (mobile alternative)
class QuickActionsBottomSheet extends StatelessWidget {
  final List<QuickAction> actions;
  final VoidCallback? onPrimaryAction;

  const QuickActionsBottomSheet({
    super.key,
    required this.actions,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          const Divider(),

          // Primary action (Create Post)
          if (onPrimaryAction != null)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.purple.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add,
                  color: Colors.white,
                ),
              ),
              title: const Text(
                'Create Post',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Share what\'s on your mind'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                onPrimaryAction!();
              },
            ),

          // Other actions
          ...actions.map((action) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                ),
              ),
              title: Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                action.onTap();
              },
            );
          }),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
