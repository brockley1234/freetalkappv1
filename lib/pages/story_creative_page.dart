import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';

class StoryCreativePage extends StatefulWidget {
  final String storyId;
  
  const StoryCreativePage({
    super.key,
    required this.storyId,
  });

  @override
  State<StoryCreativePage> createState() => _StoryCreativePageState();
}

class _StoryCreativePageState extends State<StoryCreativePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _filters = [];
  bool _isLoading = true;
  String _selectedTemplate = 'default';
  String _selectedFilter = 'none';
  int _filterIntensity = 50;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCreativeAssets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCreativeAssets() async {
    setState(() => _isLoading = true);

    try {
      final templatesResponse = await ApiService.getStoryTemplates();
      final filtersResponse = await ApiService.getStoryFilters();

      if (mounted) {
        setState(() {
          if (templatesResponse['success'] == true) {
            _templates = List<Map<String, dynamic>>.from(
              templatesResponse['data']['templates'] ?? []
            );
          }
          if (filtersResponse['success'] == true) {
            _filters = List<Map<String, dynamic>>.from(
              filtersResponse['data']['filters'] ?? []
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading creative assets: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _applyTemplate(String templateName) async {
    try {
      final response = await ApiService.applyStoryTemplate(
        storyId: widget.storyId,
        templateName: templateName,
      );

      if (response['success'] == true && mounted) {
        setState(() => _selectedTemplate = templateName);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Template applied successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to apply template'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyFilter(String filterName, int intensity) async {
    try {
      final response = await ApiService.addStoryFilter(
        storyId: widget.storyId,
        filterName: filterName,
        intensity: intensity,
      );

      if (response['success'] == true && mounted) {
        setState(() {
          _selectedFilter = filterName;
          _filterIntensity = intensity;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filter applied successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to apply filter'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Creative Tools',
          style: TextStyle(fontSize: responsive.fontLarge),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Templates'),
            Tab(text: 'Filters'),
            Tab(text: 'Stickers'),
          ],
        ),
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
                    'Loading creative tools...',
                    style: TextStyle(
                      fontSize: responsive.fontBase,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesTab(),
                _buildFiltersTab(),
                _buildStickersTab(),
              ],
            ),
    );
  }

  Widget _buildTemplatesTab() {
    final responsive = context.responsive;

    return GridView.builder(
      padding: EdgeInsets.all(responsive.paddingMedium),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: responsive.paddingMedium,
        mainAxisSpacing: responsive.paddingMedium,
        childAspectRatio: 0.8,
      ),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        final isSelected = template['name'] == _selectedTemplate;

        return GestureDetector(
          onTap: () => _applyTemplate(template['name']),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.radiusLarge),
              border: Border.all(
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.grey[300]!,
                width: isSelected ? 3 : 1,
              ),
              color: isSelected 
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
            ),
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _parseColor(template['backgroundColor']),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(responsive.radiusLarge),
                        topRight: Radius.circular(responsive.radiusLarge),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Sample',
                        style: TextStyle(
                          color: _parseColor(template['textColor']),
                          fontSize: responsive.fontLarge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.all(responsive.paddingSmall),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          template['displayName'] ?? template['name'],
                          style: TextStyle(
                            fontSize: responsive.fontMedium,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: responsive.paddingXSmall),
                        Text(
                          template['description'] ?? '',
                          style: TextStyle(
                            fontSize: responsive.fontSmall,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersTab() {
    final responsive = context.responsive;

    return Column(
      children: [
        // Filter intensity slider
        if (_selectedFilter != 'none')
          Container(
            padding: EdgeInsets.all(responsive.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filter Intensity: $_filterIntensity%',
                  style: TextStyle(
                    fontSize: responsive.fontMedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  value: _filterIntensity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: (value) {
                    setState(() => _filterIntensity = value.round());
                  },
                  onChangeEnd: (value) {
                    _applyFilter(_selectedFilter, value.round());
                  },
                ),
              ],
            ),
          ),
        
        // Filter grid
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(responsive.paddingMedium),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: responsive.paddingMedium,
              mainAxisSpacing: responsive.paddingMedium,
              childAspectRatio: 0.8,
            ),
            itemCount: _filters.length,
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isSelected = filter['name'] == _selectedFilter;

              return GestureDetector(
                onTap: () => _applyFilter(filter['name'], _filterIntensity),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(responsive.radiusMedium),
                    border: Border.all(
                      color: isSelected 
                          ? Theme.of(context).primaryColor 
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    color: isSelected 
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Filter preview (placeholder)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _getFilterColor(filter['name']),
                          borderRadius: BorderRadius.circular(responsive.radiusSmall),
                        ),
                        child: Icon(
                          _getFilterIcon(filter['name']),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      SizedBox(height: responsive.paddingSmall),
                      Text(
                        filter['displayName'] ?? filter['name'],
                        style: TextStyle(
                          fontSize: responsive.fontSmall,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStickersTab() {
    final responsive = context.responsive;
    final stickers = ['😀', '😂', '😍', '🤔', '😢', '😮', '👏', '🔥', '💯', '❤️', '👍', '👎'];

    return GridView.builder(
      padding: EdgeInsets.all(responsive.paddingMedium),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: responsive.paddingMedium,
        mainAxisSpacing: responsive.paddingMedium,
        childAspectRatio: 1,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];

        return GestureDetector(
          onTap: () => _addSticker(sticker),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.radiusMedium),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: Center(
              child: Text(
                sticker,
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addSticker(String emoji) async {
    try {
      final response = await ApiService.addStorySticker(
        storyId: widget.storyId,
        emoji: emoji,
        position: {'x': 0.5, 'y': 0.5}, // Center position
        scale: 1.0,
        rotation: 0,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sticker added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to add sticker'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceAll('#', '0xFF')));
    } catch (e) {
      return Colors.black;
    }
  }

  Color _getFilterColor(String filterName) {
    switch (filterName) {
      case 'vintage':
        return Colors.brown;
      case 'blackwhite':
        return Colors.grey;
      case 'sepia':
        return Colors.amber;
      case 'dramatic':
        return Colors.purple;
      case 'warm':
        return Colors.orange;
      case 'cool':
        return Colors.blue;
      case 'bright':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  IconData _getFilterIcon(String filterName) {
    switch (filterName) {
      case 'vintage':
        return Icons.photo_filter;
      case 'blackwhite':
        return Icons.filter_b_and_w;
      case 'sepia':
        return Icons.photo_library;
      case 'dramatic':
        return Icons.theater_comedy;
      case 'warm':
        return Icons.wb_sunny;
      case 'cool':
        return Icons.ac_unit;
      case 'bright':
        return Icons.brightness_high;
      default:
        return Icons.filter;
    }
  }
}
