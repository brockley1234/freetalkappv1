import 'package:flutter/material.dart';

enum FeedSortType {
  trending('🔥 Trending', 'trending'),
  latest('🆕 Latest', 'latest'),
  friends('👥 Friends Only', 'friends'),
  mostCommented('💬 Most Commented', 'mostCommented');

  const FeedSortType(this.label, this.value);

  final String label;
  final String value;
}

class FeedFilterTabs extends StatefulWidget {
  final FeedSortType selectedSort;
  final ValueChanged<FeedSortType> onSortChanged;

  const FeedFilterTabs({
    super.key,
    required this.selectedSort,
    required this.onSortChanged,
  });

  @override
  State<FeedFilterTabs> createState() => _FeedFilterTabsState();
}

class _FeedFilterTabsState extends State<FeedFilterTabs>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: FeedSortType.values.length,
      vsync: this,
      initialIndex: FeedSortType.values.indexOf(widget.selectedSort),
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void didUpdateWidget(FeedFilterTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSort != widget.selectedSort) {
      _tabController.animateTo(
        FeedSortType.values.indexOf(widget.selectedSort),
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      final newSort = FeedSortType.values[_tabController.index];
      widget.onSortChanged(newSort);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        color: isDark ? Colors.grey.shade900 : Colors.white,
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: FeedSortType.values
            .map(
              (sort) => Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(sort.label),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            )
            .toList(),
        labelColor: Colors.blue.shade700,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            color: Colors.blue.shade700,
            width: 3,
          ),
          insets: const EdgeInsets.symmetric(horizontal: 12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }
}
