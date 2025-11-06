import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// Navigation bar item configuration
class NavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badgeCount;

  NavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount = 0,
  });
}

/// Enhanced bottom navigation bar with animations and badges
/// Provides clear visual feedback and better UX than standard BottomNavigationBar
class EnhancedNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<NavBarItem> items;
  final Function(int) onItemTap;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? inactiveColor;

  const EnhancedNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onItemTap,
    this.backgroundColor,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkSurfaceVariant
                : AppColors.surfaceVariant,
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isActive = index == currentIndex;
              final item = items[index];

              return Expanded(
                child: NavBarButton(
                  icon: item.icon,
                  activeIcon: item.activeIcon ?? item.icon,
                  label: item.label,
                  isActive: isActive,
                  badgeCount: item.badgeCount,
                  onTap: () => onItemTap(index),
                  activeColor: activeColor ?? AppColors.primary,
                  inactiveColor: inactiveColor ?? AppColors.textTertiary,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Individual navigation button with animation
class NavBarButton extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final int badgeCount;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  const NavBarButton({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.badgeCount,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  State<NavBarButton> createState() => _NavBarButtonState();
}

class _NavBarButtonState extends State<NavBarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
  }

  @override
  void didUpdateWidget(NavBarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Animate on selection
      _scaleController.forward().then((_) {
        _scaleController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.isActive,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppBorderRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with badge
              ScaleTransition(
                scale: _scaleAnimation,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Icon
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isActive ? widget.activeIcon : widget.icon,
                        key: ValueKey(widget.isActive),
                        color: widget.isActive
                            ? widget.activeColor
                            : widget.inactiveColor,
                        size: 26,
                      ),
                    ),

                    // Badge for unread count
                    if (widget.badgeCount > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(
                              AppBorderRadius.full,
                            ),
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            widget.badgeCount > 99
                                ? '99+'
                                : '${widget.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive
                      ? widget.activeColor
                      : widget.inactiveColor,
                ),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Active indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: widget.isActive ? 24 : 0,
                decoration: BoxDecoration(
                  color: widget.activeColor,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact navigation rail for tablet/desktop
class EnhancedNavigationRail extends StatelessWidget {
  final int currentIndex;
  final List<NavBarItem> items;
  final Function(int) onItemTap;

  const EnhancedNavigationRail({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onItemTap,
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      destinations: items.map((item) {
        return NavigationRailDestination(
          icon: Badge(
            isLabelVisible: item.badgeCount > 0,
            label: Text('${item.badgeCount}'),
            child: Icon(item.icon),
          ),
          selectedIcon: Badge(
            isLabelVisible: item.badgeCount > 0,
            label: Text('${item.badgeCount}'),
            child: Icon(item.activeIcon ?? item.icon),
          ),
          label: Text(item.label),
        );
      }).toList(),
    );
  }
}
