import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';

class StoryInsightsDashboard extends StatefulWidget {
  final String? userId;
  final String? storyId;
  
  const StoryInsightsDashboard({
    super.key,
    this.userId,
    this.storyId,
  });

  @override
  State<StoryInsightsDashboard> createState() => _StoryInsightsDashboardState();
}

class _StoryInsightsDashboardState extends State<StoryInsightsDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _analytics;
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String _selectedTimeframe = '7d';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      if (widget.storyId != null) {
        final response = await ApiService.getStoryAnalytics(widget.storyId!);
        if (response['success'] == true && mounted) {
          setState(() {
            _analytics = response['data'];
            _isLoading = false;
          });
        }
      } else if (widget.userId != null) {
        final response = await ApiService.getUserAnalyticsSummary(widget.userId!);
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

    return SizedBox(
      height: 400,
      child: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: responsive.paddingMedium),
                  Text(
                    'Loading insights...',
                    style: TextStyle(
                      fontSize: responsive.fontBase,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Timeframe selector
                Container(
                  padding: EdgeInsets.symmetric(horizontal: responsive.paddingMedium),
                  child: Row(
                    children: [
                      Text(
                        'Timeframe:',
                        style: TextStyle(
                          fontSize: responsive.fontMedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: responsive.paddingSmall),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['24h', '7d', '30d', '90d'].map((timeframe) {
                              final isSelected = _selectedTimeframe == timeframe;
                              return Padding(
                                padding: EdgeInsets.only(right: responsive.paddingSmall),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedTimeframe = timeframe);
                                    _loadAnalytics();
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: responsive.paddingMedium,
                                      vertical: responsive.paddingSmall,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected 
                                          ? Theme.of(context).primaryColor 
                                          : Colors.grey[200],
                                      borderRadius: BorderRadius.circular(responsive.radiusMedium),
                                    ),
                                    child: Text(
                                      timeframe,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab bar
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Engagement'),
                    Tab(text: 'Audience'),
                  ],
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildEngagementTab(),
                      _buildAudienceTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    if (widget.storyId != null && _analytics != null) {
      return _buildStoryOverview();
    } else if (widget.userId != null && _summary != null) {
      return _buildUserOverview();
    }
    
    return const Center(child: Text('No data available'));
  }

  Widget _buildStoryOverview() {
    final responsive = context.responsive;
    final analytics = _analytics!['analytics'] ?? {};
    final views = analytics['views'] ?? {};
    final engagement = analytics['engagement'] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
        children: [
          // Key metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Views',
                  '${views['total'] ?? 0}',
                  Icons.visibility,
                  Colors.blue,
                ),
              ),
              SizedBox(width: responsive.paddingSmall),
              Expanded(
                child: _buildMetricCard(
                  'Engagement',
                  '${(engagement['rate'] ?? 0).toStringAsFixed(1)}%',
                  Icons.favorite,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingMedium),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Reactions',
                  '${engagement['reactions'] ?? 0}',
                  Icons.thumb_up,
                  Colors.orange,
                ),
              ),
              SizedBox(width: responsive.paddingSmall),
              Expanded(
                child: _buildMetricCard(
                  'Shares',
                  '${engagement['shares'] ?? 0}',
                  Icons.share,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Performance chart
          _buildPerformanceChart(),
        ],
      ),
    );
  }

  Widget _buildUserOverview() {
    final responsive = context.responsive;
    final summary = _summary!['summary'] ?? {};

    return SingleChildScrollView(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
        children: [
          // Summary metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Stories',
                  '${summary['totalStories'] ?? 0}',
                  Icons.collections,
                  Colors.blue,
                ),
              ),
              SizedBox(width: responsive.paddingSmall),
              Expanded(
                child: _buildMetricCard(
                  'Total Views',
                  '${summary['totalViews'] ?? 0}',
                  Icons.visibility,
                  Colors.green,
                ),
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingMedium),
          
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Avg Views',
                  '${summary['avgViewsPerStory'] ?? 0}',
                  Icons.trending_up,
                  Colors.orange,
                ),
              ),
              SizedBox(width: responsive.paddingSmall),
              Expanded(
                child: _buildMetricCard(
                  'Engagement',
                  '${summary['engagementRate'] ?? 0}%',
                  Icons.favorite,
                  Colors.red,
                ),
              ),
            ],
          ),
          
          SizedBox(height: responsive.paddingLarge),
          
          // Media type performance
          _buildMediaTypeChart(),
        ],
      ),
    );
  }

  Widget _buildEngagementTab() {
    if (widget.storyId != null && _analytics != null) {
      final engagement = _analytics!['analytics']['engagement'] ?? {};
      return _buildEngagementBreakdown(engagement);
    }
    
    return const Center(child: Text('Engagement data not available'));
  }

  Widget _buildAudienceTab() {
    if (widget.storyId != null && _analytics != null) {
      final demographics = _analytics!['analytics']['demographics'] ?? {};
      return _buildAudienceInsights(demographics);
    }
    
    return const Center(child: Text('Audience data not available'));
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    final responsive = context.responsive;
    
    return Container(
      padding: EdgeInsets.all(responsive.paddingMedium),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(responsive.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: responsive.iconLarge),
          SizedBox(height: responsive.paddingSmall),
          Text(
            value,
            style: TextStyle(
              fontSize: responsive.fontLarge,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: responsive.fontSmall,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    final responsive = context.responsive;
    
    // Mock data for demonstration
    final data = [
      {'day': 'Mon', 'views': 120},
      {'day': 'Tue', 'views': 150},
      {'day': 'Wed', 'views': 180},
      {'day': 'Thu', 'views': 200},
      {'day': 'Fri', 'views': 160},
      {'day': 'Sat', 'views': 140},
      {'day': 'Sun', 'views': 100},
    ];

    return Container(
      height: 200,
      padding: EdgeInsets.all(responsive.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsive.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Views Over Time',
            style: TextStyle(
              fontSize: responsive.fontMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsive.paddingMedium),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          data[value.toInt()]['day'].toString(),
                          style: TextStyle(fontSize: responsive.fontSmall),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => 
                      FlSpot(e.key.toDouble(), ((e.value['views'] as int?) ?? 0).toDouble())
                    ).toList(),
                    isCurved: true,
                    color: Theme.of(context).primaryColor,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementBreakdown(Map<String, dynamic> engagement) {
    final responsive = context.responsive;
    final reactions = engagement['reactions'] ?? 0;
    final shares = engagement['shares'] ?? 0;
    final replies = engagement['replies'] ?? 0;

    return Padding(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
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
    );
  }

  Widget _buildMediaTypeChart() {
    final responsive = context.responsive;
    final mediaTypeStats = List<Map<String, dynamic>>.from(
      _summary!['mediaTypeStats'] ?? []
    );

    if (mediaTypeStats.isEmpty) {
      return const Center(child: Text('No media type data available'));
    }

    return Container(
      height: 200,
      padding: EdgeInsets.all(responsive.paddingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(responsive.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance by Media Type',
            style: TextStyle(
              fontSize: responsive.fontMedium,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsive.paddingMedium),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: mediaTypeStats.map((e) => e['avgViews']).reduce((a, b) => a > b ? a : b) + 10,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < mediaTypeStats.length) {
                          return Text(
                            _getMediaTypeName(mediaTypeStats[index]['type']),
                            style: TextStyle(fontSize: responsive.fontSmall),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(fontSize: responsive.fontSmall),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: mediaTypeStats.asMap().entries.map((e) {
                  final index = e.key;
                  final stat = e.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: stat['avgViews'].toDouble(),
                        color: _getMediaTypeColor(stat['type']),
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceInsights(Map<String, dynamic> demographics) {
    final responsive = context.responsive;
    final peakHour = demographics['peakHour'];
    final viewTimes = List<int>.from(demographics['viewTimes'] ?? []);

    return Padding(
      padding: EdgeInsets.all(responsive.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audience Insights',
            style: TextStyle(
              fontSize: responsive.fontLarge,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: responsive.paddingMedium),
          
          if (peakHour != null)
            _buildInsightCard(
              'Peak Viewing Time',
              '$peakHour:00',
              Icons.access_time,
              Colors.blue,
            ),
          
          SizedBox(height: responsive.paddingMedium),
          
          if (viewTimes.isNotEmpty)
            _buildInsightCard(
              'Total View Sessions',
              '${viewTimes.length}',
              Icons.people,
              Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, IconData icon, Color color) {
    final responsive = context.responsive;
    
    return Container(
      padding: EdgeInsets.all(responsive.paddingMedium),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(responsive.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: responsive.iconMedium),
          SizedBox(width: responsive.paddingSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: responsive.fontBase,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: responsive.fontMedium,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMediaTypeName(String type) {
    switch (type) {
      case 'image':
        return 'Images';
      case 'video':
        return 'Videos';
      case 'text':
        return 'Text';
      default:
        return type;
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
}
