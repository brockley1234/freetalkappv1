import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Widget to display story analytics dashboard for story creators
/// 
/// Shows:
/// - Total views, reactions, replies, shares
/// - Engagement rate percentage
/// - Views over time (simplified)
/// - Top reactions breakdown
class StoryAnalyticsDashboard extends StatefulWidget {
  final String storyId;

  const StoryAnalyticsDashboard({
    super.key,
    required this.storyId,
  });

  @override
  State<StoryAnalyticsDashboard> createState() =>
      _StoryAnalyticsDashboardState();
}

class _StoryAnalyticsDashboardState extends State<StoryAnalyticsDashboard> {
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    _analyticsFuture = ApiService.getStoryAnalytics(widget.storyId)
        .then<Map<String, dynamic>>((result) {
          if (result['success']) {
            return result['data'] ?? {};
          }
          throw Exception(result['message'] ?? 'Failed to load analytics');
        })
        .catchError((e) {
          debugPrint('❌ Error loading analytics: $e');
          return <String, dynamic>{};
        });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _analyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading analytics',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red,
                  ),
            ),
          );
        }

        final analytics = snapshot.data ?? {};
        final viewsCount = analytics['viewsCount'] ?? 0;
        final reactionsCount = analytics['reactionsCount'] ?? 0;
        final repliesCount = analytics['repliesCount'] ?? 0;
        final sharesCount = analytics['sharesCount'] ?? 0;
        final engagementRate = analytics['engagementRate'] ?? 0.0;
        final topReactions = analytics['topReactions'] ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Story Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // Key metrics grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMetricCard(
                    context: context,
                    icon: Icons.visibility,
                    label: 'Views',
                    value: viewsCount.toString(),
                    color: Colors.blue,
                  ),
                  _buildMetricCard(
                    context: context,
                    icon: Icons.favorite,
                    label: 'Reactions',
                    value: reactionsCount.toString(),
                    color: Colors.pink,
                  ),
                  _buildMetricCard(
                    context: context,
                    icon: Icons.comment,
                    label: 'Replies',
                    value: repliesCount.toString(),
                    color: Colors.green,
                  ),
                  _buildMetricCard(
                    context: context,
                    icon: Icons.share,
                    label: 'Shares',
                    value: sharesCount.toString(),
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Engagement rate card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engagement Rate',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${engagementRate.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    Icon(
                      Icons.trending_up,
                      color: Colors.blue.shade700,
                      size: 48,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Top reactions
              if (topReactions.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Top Reactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      children: topReactions.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            final emoji = entry.value.key;
                            final count = entry.value.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: count /
                                            (topReactions.values
                                                    .reduce((a, b) =>
                                                        a > b ? a : b) as int)
                                                .toDouble(),
                                        minHeight: 8,
                                        backgroundColor:
                                            Colors.grey.shade200,
                                        valueColor: const AlwaysStoppedAnimation<
                                            Color>(Colors.pink),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    count.toString(),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
