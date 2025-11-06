import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';
import '../utils/time_utils.dart';

class StoryAnalyticsPage extends StatefulWidget {
  final String? storyId;
  final String? userId;
  
  const StoryAnalyticsPage({
    super.key,
    this.storyId,
    this.userId,
  });

  @override
  State<StoryAnalyticsPage> createState() => _StoryAnalyticsPageState();
}

class _StoryAnalyticsPageState extends State<StoryAnalyticsPage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _currentUserId;
  String? _targetUserId;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _targetUserId = widget.userId ?? _currentUserId;
    await _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      if (widget.storyId != null) {
        // Load specific story analytics
        final response = await ApiService.getStoryAnalytics(widget.storyId!);
        if (response['success'] == true && mounted) {
          setState(() {
            _analytics = response['data'];
            _isLoading = false;
          });
        }
      } else if (_targetUserId != null) {
        // Load user analytics summary
        final response = await ApiService.getUserAnalyticsSummary(_targetUserId!);
        if (response['success'] == true && mounted) {
          setState(() {
            _summary = response['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.storyId != null ? 'Story Analytics' : 'Analytics',
          style: TextStyle(fontSize: responsive.fontLarge),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
        bottom: widget.storyId == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Stories'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: responsive.paddingMedium),
                  Text(
                    'Loading analytics...',
                    style: TextStyle(
                      fontSize: responsive.fontBase,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : widget.storyId != null
              ? _buildStoryAnalytics()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildStoriesTab(),
                  ],
                ),
    );
  }

  Widget _buildStoryAnalytics() {
    if (_analytics == null) {
      return const Center(child: Text('No analytics data available'));
    }

    final responsive = context.responsive;
    final analytics = _analytics!['analytics'] ?? {};
    final views = analytics['views'] ?? {};
    final engagement = analytics['engagement'] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Overview
          _buildAnalyticsCard(
            title: 'Performance Overview',
            children: [
              _buildMetricRow(
                'Total Views',
                '${views['total'] ?? 0}',
                Icons.visibility,
                Colors.blue,
              ),
              _buildMetricRow(
                'Unique Views',
                '${views['unique'] ?? 0}',
                Icons.people,
                Colors.green,
              ),
              _buildMetricRow(
                'Views per Hour',
                '${(views['rate'] ?? 0).toStringAsFixed(1)}',
                Icons.trending_up,
                Colors.orange,
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Engagement Metrics
          _buildAnalyticsCard(
            title: 'Engagement',
            children: [
              _buildMetricRow(
                'Reactions',
                '${engagement['reactions'] ?? 0}',
                Icons.favorite,
                Colors.red,
              ),
              _buildMetricRow(
                'Shares',
                '${engagement['shares'] ?? 0}',
                Icons.share,
                Colors.purple,
              ),
              _buildMetricRow(
                'Replies',
                '${engagement['replies'] ?? 0}',
                Icons.comment,
                Colors.blue,
              ),
              _buildMetricRow(
                'Engagement Rate',
                '${(engagement['rate'] ?? 0).toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.green,
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Engagement Chart
          _buildEngagementChart(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_summary == null) {
      return const Center(child: Text('No analytics data available'));
    }

    final responsive = context.responsive;
    final summary = _summary!['summary'] ?? {};
    final bestPerforming = _summary!['bestPerforming'];
    final mediaTypeStats = List<Map<String, dynamic>>.from(
      _summary!['mediaTypeStats'] ?? []
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Stats
          _buildAnalyticsCard(
            title: '${_summary!['timeframe']} Summary',
            children: [
              _buildMetricRow(
                'Total Stories',
                '${summary['totalStories'] ?? 0}',
                Icons.collections,
                Colors.blue,
              ),
              _buildMetricRow(
                'Total Views',
                '${summary['totalViews'] ?? 0}',
                Icons.visibility,
                Colors.green,
              ),
              _buildMetricRow(
                'Avg Views/Story',
                '${summary['avgViewsPerStory'] ?? 0}',
                Icons.trending_up,
                Colors.orange,
              ),
              _buildMetricRow(
                'Engagement Rate',
                '${summary['engagementRate'] ?? 0}%',
                Icons.favorite,
                Colors.red,
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Best Performing Story
          if (bestPerforming != null)
            _buildAnalyticsCard(
              title: 'Best Performing Story',
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getMediaTypeColor(bestPerforming['mediaType']),
                    child: Icon(
                      _getMediaTypeIcon(bestPerforming['mediaType']),
                      color: Colors.white,
                    ),
                  ),
                  title: Text('${bestPerforming['views']} views'),
                  subtitle: Text(
                    '${bestPerforming['engagement']} engagement • ${TimeUtils.formatMessageTimestamp(bestPerforming['createdAt'])}',
                  ),
                ),
              ],
            ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Media Type Performance
          if (mediaTypeStats.isNotEmpty)
            _buildAnalyticsCard(
              title: 'Performance by Type',
              children: mediaTypeStats.map((stat) => 
                _buildMetricRow(
                  _getMediaTypeName(stat['type']),
                  '${stat['avgViews']} avg views',
                  _getMediaTypeIcon(stat['type']),
                  _getMediaTypeColor(stat['type']),
                ),
              ).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildStoriesTab() {
    // This would show a list of individual stories with their analytics
    return const Center(
      child: Text('Individual story analytics will be shown here'),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required List<Widget> children,
  }) {
    final responsive = context.responsive;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(responsive.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: responsive.fontLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.paddingMedium),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final responsive = context.responsive;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.paddingSmall),
      child: Row(
        children: [
          Icon(icon, color: color, size: responsive.iconMedium),
          SizedBox(width: responsive.paddingSmall),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: responsive.fontBase),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: responsive.fontMedium,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementChart() {
    final responsive = context.responsive;
    final analytics = _analytics!['analytics'] ?? {};
    final engagement = analytics['engagement'] ?? {};
    
    final reactions = engagement['reactions'] ?? 0;
    final shares = engagement['shares'] ?? 0;
    final replies = engagement['replies'] ?? 0;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(responsive.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Breakdown',
              style: TextStyle(
                fontSize: responsive.fontLarge,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: responsive.paddingMedium),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: reactions.toDouble(),
                      title: 'Reactions\n$reactions',
                      color: Colors.red,
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: responsive.fontSmall,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: shares.toDouble(),
                      title: 'Shares\n$shares',
                      color: Colors.purple,
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: responsive.fontSmall,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: replies.toDouble(),
                      title: 'Replies\n$replies',
                      color: Colors.blue,
                      radius: 60,
                      titleStyle: TextStyle(
                        fontSize: responsive.fontSmall,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getMediaTypeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.videocam;
      case 'text':
        return Icons.text_fields;
      default:
        return Icons.help;
    }
  }

  Color _getMediaTypeColor(String type) {
    switch (type) {
      case 'image':
        return Colors.blue;
      case 'video':
        return Colors.red;
      case 'text':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getMediaTypeName(String type) {
    switch (type) {
      case 'image':
        return 'Images';
      case 'video':
        return 'Videos';
      case 'text':
        return 'Text Stories';
      default:
        return type;
    }
  }
}
