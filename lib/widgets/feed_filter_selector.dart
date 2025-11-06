import 'package:flutter/material.dart';

enum FeedFilterType {
  all,
  following,
  trending,
  recent,
}

enum FeedSortType {
  newest,
  mostLiked,
  mostCommented,
  trending,
}

class FeedFilterSelector extends StatefulWidget {
  final FeedFilterType selectedFilter;
  final FeedSortType selectedSort;
  final Function(FeedFilterType) onFilterChanged;
  final Function(FeedSortType) onSortChanged;

  const FeedFilterSelector({
    super.key,
    required this.selectedFilter,
    required this.selectedSort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  @override
  State<FeedFilterSelector> createState() => _FeedFilterSelectorState();
}

class _FeedFilterSelectorState extends State<FeedFilterSelector> {
  late FeedFilterType _localFilter;
  late FeedSortType _localSort;

  @override
  void initState() {
    super.initState();
    _localFilter = widget.selectedFilter;
    _localSort = widget.selectedSort;
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                Text(
                  'Filter Feed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),

                // Filter options
                _buildFilterOption(
                  icon: Icons.home_outlined,
                  label: 'All Posts',
                  value: FeedFilterType.all,
                  isSelected: _localFilter == FeedFilterType.all,
                  onTap: () => _updateFilter(FeedFilterType.all),
                ),
                _buildFilterOption(
                  icon: Icons.people_outline,
                  label: 'Following',
                  value: FeedFilterType.following,
                  isSelected: _localFilter == FeedFilterType.following,
                  onTap: () => _updateFilter(FeedFilterType.following),
                ),
                _buildFilterOption(
                  icon: Icons.trending_up,
                  label: 'Trending',
                  value: FeedFilterType.trending,
                  isSelected: _localFilter == FeedFilterType.trending,
                  onTap: () => _updateFilter(FeedFilterType.trending),
                ),
                _buildFilterOption(
                  icon: Icons.new_releases_outlined,
                  label: 'Recent',
                  value: FeedFilterType.recent,
                  isSelected: _localFilter == FeedFilterType.recent,
                  onTap: () => _updateFilter(FeedFilterType.recent),
                ),

                const SizedBox(height: 24),

                // Title
                Text(
                  'Sort By',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 16),

                // Sort options
                _buildSortOption(
                  icon: Icons.schedule_outlined,
                  label: 'Newest',
                  value: FeedSortType.newest,
                  isSelected: _localSort == FeedSortType.newest,
                  onTap: () => _updateSort(FeedSortType.newest),
                ),
                _buildSortOption(
                  icon: Icons.favorite_outline,
                  label: 'Most Liked',
                  value: FeedSortType.mostLiked,
                  isSelected: _localSort == FeedSortType.mostLiked,
                  onTap: () => _updateSort(FeedSortType.mostLiked),
                ),
                _buildSortOption(
                  icon: Icons.comment_outlined,
                  label: 'Most Commented',
                  value: FeedSortType.mostCommented,
                  isSelected: _localSort == FeedSortType.mostCommented,
                  onTap: () => _updateSort(FeedSortType.mostCommented),
                ),
                _buildSortOption(
                  icon: Icons.flash_on,
                  label: 'Trending',
                  value: FeedSortType.trending,
                  isSelected: _localSort == FeedSortType.trending,
                  onTap: () => _updateSort(FeedSortType.trending),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _localFilter = widget.selectedFilter;
                          _localSort = widget.selectedSort;
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onFilterChanged(_localFilter);
                          widget.onSortChanged(_localSort);
                        },
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateFilter(FeedFilterType filter) {
    setState(() {
      _localFilter = filter;
    });
  }

  void _updateSort(FeedSortType sort) {
    setState(() {
      _localSort = sort;
    });
  }

  Widget _buildFilterOption({
    required IconData icon,
    required String label,
    required FeedFilterType value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey.shade600,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.blue : Colors.grey.shade800,
        ),
      ),
      trailing: isSelected
          ? Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSortOption({
    required IconData icon,
    required String label,
    required FeedSortType value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey.shade600,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.blue : Colors.grey.shade800,
        ),
      ),
      trailing: isSelected
          ? Container(
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.blue),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            )
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Filter button with badge
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showFilterMenu,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.blue.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.blue.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _getFilterLabel(_localFilter),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Sort button
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showFilterMenu,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sort, color: Colors.grey.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _getSortLabel(_localSort),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(FeedFilterType filter) {
    switch (filter) {
      case FeedFilterType.all:
        return 'All Posts';
      case FeedFilterType.following:
        return 'Following';
      case FeedFilterType.trending:
        return 'Trending';
      case FeedFilterType.recent:
        return 'Recent';
    }
  }

  String _getSortLabel(FeedSortType sort) {
    switch (sort) {
      case FeedSortType.newest:
        return 'Newest';
      case FeedSortType.mostLiked:
        return 'Most Liked';
      case FeedSortType.mostCommented:
        return 'Most Commented';
      case FeedSortType.trending:
        return 'Trending';
    }
  }
}
