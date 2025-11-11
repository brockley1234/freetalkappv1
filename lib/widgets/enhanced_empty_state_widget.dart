import 'package:flutter/material.dart';
import '../utils/responsive_dimensions.dart';

/// Enhanced empty state widget with actionable items and better UX
class EnhancedEmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<EmptyStateAction>? suggestedActions;
  final bool showIllustration;

  const EnhancedEmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.suggestedActions,
    this.showIllustration = true,
  }) : super();

  @override
  State<EnhancedEmptyStateWidget> createState() =>
      _EnhancedEmptyStateWidgetState();
}

class _EnhancedEmptyStateWidgetState extends State<EnhancedEmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveDimensions.getHorizontalPadding(context);
    final spacing = ResponsiveDimensions.getItemSpacing(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return FadeTransition(
      opacity: _fadeController,
      child: SingleChildScrollView(
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: padding, vertical: spacing * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: spacing * 2),

              // Animated illustration/icon
              if (widget.showIllustration)
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                    CurvedAnimation(
                        parent: _fadeController, curve: Curves.easeOutBack),
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 50,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),

              SizedBox(height: spacing * 2),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),

              SizedBox(height: spacing),

              // Description
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing),
                child: Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        height: 1.6,
                      ),
                ),
              ),

              SizedBox(height: spacing * 2),

              // Primary action button
              if (widget.actionLabel != null && widget.onAction != null)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: widget.onAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(widget.actionLabel!),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing * 2,
                        vertical: spacing * 1.25,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),

              // Suggested actions
              if (widget.suggestedActions != null &&
                  widget.suggestedActions!.isNotEmpty) ...[
                SizedBox(height: spacing * 2),
                Text(
                  'Suggested actions:',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                SizedBox(height: spacing),
                if (isMobile)
                  _buildMobileActionsList(context, spacing)
                else
                  _buildDesktopActionsGrid(context, spacing),
              ],

              SizedBox(height: spacing * 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileActionsList(BuildContext context, double spacing) {
    return Column(
      children: widget.suggestedActions!
          .map(
            (action) => Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: _buildActionCard(context, action, spacing),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDesktopActionsGrid(BuildContext context, double spacing) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: widget.suggestedActions!
          .map((action) => _buildActionCard(context, action, spacing))
          .toList(),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    EmptyStateAction action,
    double spacing,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          padding: EdgeInsets.all(spacing),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: action.color.withValues(alpha: 0.15),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 24,
                ),
              ),
              SizedBox(height: spacing * 0.75),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (action.description != null) ...[
                SizedBox(height: spacing * 0.25),
                Text(
                  action.description!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Model for suggested empty state actions
class EmptyStateAction {
  final String label;
  final String? description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  EmptyStateAction({
    required this.label,
    this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
