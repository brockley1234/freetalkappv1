import 'package:flutter/material.dart';
import '../../services/crisis_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/url_utils.dart';
import 'crisis_detail_page.dart';
import 'create_crisis_page.dart';
import 'crisis_utils.dart';
import 'crisis_widgets.dart';

class CrisisResponsePage extends StatefulWidget {
  const CrisisResponsePage({super.key});

  @override
  State<CrisisResponsePage> createState() => _CrisisResponsePageState();
}

class _CrisisResponsePageState extends State<CrisisResponsePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CrisisService _crisisService;
  String? _selectedSeverity;
  String? _selectedCrisisType;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _crisisService = CrisisService();
    _crisisService.addListener(_onCrisisServiceUpdate);
    _loadData();
  }

  void _onCrisisServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    if (_isLoading && !_isInitialLoad) return;

    setState(() => _isLoading = true);
    try {
      await _crisisService.init();
      await _crisisService.fetchActiveCrisis(
        severity: _selectedSeverity,
        crisisType: _selectedCrisisType,
      );
      await _crisisService.fetchUserCrisisHistory();
      CrisisAnalytics.logCrisisViewed('all_crises');
    } catch (e) {
      AppLogger().error('Error loading crisis data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading crises: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    }
  }

  List<CrisisResponse> _getFilteredCrises(List<CrisisResponse> crises) {
    return crises.where((crisis) {
      final searchLower = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          crisis.description.toLowerCase().contains(searchLower) ||
          crisis.crisisType.toLowerCase().contains(searchLower) ||
          crisis.userName.toLowerCase().contains(searchLower);
      return matchesSearch;
    }).toList();
  }

  @override
  void dispose() {
    _crisisService.removeListener(_onCrisisServiceUpdate);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crisis Response'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 60),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search crises...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                      text: 'Active Alerts',
                      icon: Icon(Icons.warning_amber_rounded)),
                  Tab(text: 'My History', icon: Icon(Icons.history)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter crises',
          ),
        ],
      ),
      body: _isInitialLoad
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildActiveCrisesTab(),
                _buildUserHistoryTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateCrisisPage(),
            ),
          ).then((_) => _loadData());
        },
        backgroundColor: Colors.red.shade700,
        icon: const Icon(Icons.sos),
        label: const Text('Request Help'),
        tooltip: 'Create a new crisis alert',
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => const CrisisCardSkeleton(),
    );
  }

  Widget _buildActiveCrisesTab() {
    final filteredCrises = _getFilteredCrises(_crisisService.activeCrises);

    if (filteredCrises.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EnhancedEmptyState(
              emptyState: _searchQuery.isNotEmpty
                  ? EmptyState.searchEmpty()
                  : EmptyState.noCrises(),
              onRetry: _loadData,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredCrises.length,
        itemBuilder: (context, index) {
          final crisis = filteredCrises[index];
          return _buildCrisisCard(crisis);
        },
      ),
    );
  }

  Widget _buildUserHistoryTab() {
    final filteredHistory =
        _getFilteredCrises(_crisisService.userCrisisHistory);

    if (filteredHistory.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: EnhancedEmptyState(
              emptyState: EmptyState.noCrisisHistory(),
              onRetry: _loadData,
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredHistory.length,
        itemBuilder: (context, index) {
          final crisis = filteredHistory[index];
          return _buildCrisisCard(crisis);
        },
      ),
    );
  }

  Widget _buildCrisisCard(CrisisResponse crisis) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CrisisDetailPage(crisisId: crisis.id),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EnhancedSeverityBadge(severity: crisis.severity),
                  const SizedBox(width: 8),
                  EnhancedCrisisTypeBadge(crisisType: crisis.crisisType),
                  const Spacer(),
                  EnhancedStatusIndicator(status: crisis.status),
                ],
              ),
              const SizedBox(height: 12),
              _buildCrisisUserSection(crisis),
              const SizedBox(height: 12),
              Text(
                crisis.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if (crisis.location?['address'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        crisis.location!['address'],
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildCrisisStats(crisis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrisisUserSection(CrisisResponse crisis) {
    return Row(
      children: [
        if (!crisis.isAnonymous && crisis.userProfilePicture != null)
          CircleAvatar(
            backgroundImage:
                UrlUtils.getAvatarImageProvider(crisis.userProfilePicture),
            radius: 20,
          )
        else
          CircleAvatar(
            backgroundColor: Colors.grey.shade300,
            radius: 20,
            child: Icon(Icons.person, color: Colors.grey.shade600),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                crisis.isAnonymous ? 'Anonymous' : crisis.userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                CrisisTimeUtils.getTimeAgo(crisis.createdAt),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrisisStats(CrisisResponse crisis) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatBadge(
          Icons.people,
          '${crisis.helpers.length}',
          'Helpers',
          Colors.blue,
        ),
        _buildStatBadge(
          Icons.verified_user,
          '${crisis.safetyChecks.length}',
          'Checks',
          Colors.green,
        ),
        _buildStatBadge(
          Icons.update,
          '${crisis.updates.length}',
          'Updates',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatBadge(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$value $label',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filter Crisis Alerts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_selectedSeverity != null || _selectedCrisisType != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedSeverity = null;
                        _selectedCrisisType = null;
                      });
                      Navigator.pop(context);
                      _loadData();
                    },
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Severity Level',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final severity in CrisisConstants.severityLevels)
                  FilterChip(
                    label: Text(CrisisFormatting.formatStatus(severity)),
                    selected: _selectedSeverity == severity,
                    onSelected: (selected) {
                      setState(() {
                        _selectedSeverity = selected ? severity : null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Crisis Type',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in CrisisConstants.crisisTypes)
                  FilterChip(
                    label: Text(type.value),
                    selected: _selectedCrisisType == type.key,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCrisisType = selected ? type.key : null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadData();
                    },
                    child: const Text('Apply Filters'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
