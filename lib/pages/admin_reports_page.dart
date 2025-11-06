import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/api_service.dart';
import '../utils/url_utils.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _isLoading = true;
  List<dynamic> _reports = [];
  Map<String, dynamic>? _stats;
  String _filterStatus = 'all';
  String _filterType = 'all';
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!_hasMore && _currentPage > 1) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.getReports(
        page: _currentPage,
        limit: 20,
        status: _filterStatus == 'all' ? null : _filterStatus,
        reportType: _filterType == 'all' ? null : _filterType,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final List<dynamic> newReports = data['reports'] ?? [];
        final pagination = data['pagination'];
        final stats = data['stats'];

        setState(() {
          if (_currentPage == 1) {
            _reports = newReports;
          } else {
            _reports.addAll(newReports);
          }
          _stats = stats;
          _hasMore =
              pagination != null && pagination['page'] < pagination['pages'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshReports() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _reports = [];
    });
    await _loadReports();
  }

  void _changeFilter(String status, String type) {
    setState(() {
      _filterStatus = status;
      _filterType = type;
      _currentPage = 1;
      _hasMore = true;
      _reports = [];
    });
    _loadReports();
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReportDetailsSheet(
        report: report,
        onReviewed: _refreshReports,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics cards
          if (_stats != null) _buildStatsCards(),

          // Filter chips
          _buildFilterChips(),

          // Reports list
          Expanded(
            child: _isLoading && _reports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.report_off,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No reports found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshReports,
                        child: ListView.builder(
                          itemCount: _reports.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _reports.length) {
                              if (_hasMore) {
                                _currentPage++;
                                _loadReports();
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            final report = _reports[index];
                            return _buildReportCard(report);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final total = _stats!['total'] ?? 0;
    final pending = _stats!['pending'] ?? 0;
    final resolved = _stats!['resolved'] ?? 0;
    final dismissed = _stats!['dismissed'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard('Total', total.toString(), Colors.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('Pending', pending.toString(), Colors.orange),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                _buildStatCard('Resolved', resolved.toString(), Colors.green),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                _buildStatCard('Dismissed', dismissed.toString(), Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('All', _filterStatus == 'all', () {
            _changeFilter('all', _filterType);
          }),
          _buildFilterChip('Pending', _filterStatus == 'pending', () {
            _changeFilter('pending', _filterType);
          }),
          _buildFilterChip('Resolved', _filterStatus == 'resolved', () {
            _changeFilter('resolved', _filterType);
          }),
          _buildFilterChip('Dismissed', _filterStatus == 'dismissed', () {
            _changeFilter('dismissed', _filterType);
          }),
          const SizedBox(width: 16),
          _buildFilterChip('Users', _filterType == 'user', () {
            _changeFilter(_filterStatus, 'user');
          }),
          _buildFilterChip('Posts', _filterType == 'post', () {
            _changeFilter(_filterStatus, 'post');
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue,
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final reportType = report['reportType'] ?? 'unknown';
    final reason = report['reason'] ?? 'No reason';
    final status = report['status'] ?? 'pending';
    final createdAt = report['createdAt'];
    final reporter = report['reporter'];
    final reportedUser = report['reportedUser'];
    final reportedPost = report['reportedPost'];

    final reporterName = reporter?['name'] ?? 'Unknown';
    final targetName = reportType == 'user'
        ? (reportedUser?['name'] ?? 'Unknown')
        : (reportedPost?['author']?['name'] ?? 'Unknown');

    Color statusColor;
    switch (status) {
      case 'pending':
        statusColor = Colors.orange;
        break;
      case 'reviewing':
        statusColor = Colors.blue;
        break;
      case 'resolved':
        statusColor = Colors.green;
        break;
      case 'dismissed':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showReportDetails(report),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    reportType == 'user' ? Icons.person : Icons.article,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Report: ${_formatReason(reason)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Reporter: $reporterName',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Target: $targetName (${reportType == 'user' ? 'User' : 'Post'})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              if (report['details'] != null &&
                  report['details'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  report['details'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    createdAt != null
                        ? timeago.format(DateTime.parse(createdAt))
                        : 'Unknown time',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showReportDetails(report),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Details'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatReason(String reason) {
    return reason
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Reports'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Status:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterStatus == 'all',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter('all', _filterType);
                  },
                ),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _filterStatus == 'pending',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter('pending', _filterType);
                  },
                ),
                ChoiceChip(
                  label: const Text('Resolved'),
                  selected: _filterStatus == 'resolved',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter('resolved', _filterType);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Type:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterType == 'all',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter(_filterStatus, 'all');
                  },
                ),
                ChoiceChip(
                  label: const Text('Users'),
                  selected: _filterType == 'user',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter(_filterStatus, 'user');
                  },
                ),
                ChoiceChip(
                  label: const Text('Posts'),
                  selected: _filterType == 'post',
                  onSelected: (_) {
                    Navigator.pop(context);
                    _changeFilter(_filterStatus, 'post');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Report Details Bottom Sheet
class _ReportDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> report;
  final VoidCallback onReviewed;

  const _ReportDetailsSheet({
    required this.report,
    required this.onReviewed,
  });

  @override
  State<_ReportDetailsSheet> createState() => _ReportDetailsSheetState();
}

class _ReportDetailsSheetState extends State<_ReportDetailsSheet> {
  bool _isProcessing = false;
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _reviewReport(String status, String action) async {
    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.reviewReport(
        widget.report['_id'],
        status: status,
        adminNotes: _notesController.text.trim(),
        actionTaken: action,
      );

      setState(() => _isProcessing = false);

      if (!mounted) return;

      Navigator.pop(context);

      if (result['success'] == true) {
        widget.onReviewed();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report reviewed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to review report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unsuspendUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsuspend User'),
        content: const Text(
          'Are you sure you want to unsuspend this user? They will regain full access to their account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unsuspend'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await ApiService.unsuspendUser(userId);

      if (!mounted) return;

      if (result['success'] == true) {
        widget.onReviewed();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User unsuspended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to unsuspend user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unbanUser(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unban User'),
        content: const Text(
          'Are you sure you want to unban this user? They will regain full access to their account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unban'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await ApiService.unbanUser(userId);

      if (!mounted) return;

      if (result['success'] == true) {
        widget.onReviewed();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User unbanned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to unban user'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportType = widget.report['reportType'] ?? 'unknown';
    final reason = widget.report['reason'] ?? 'No reason';
    final status = widget.report['status'] ?? 'pending';
    final details = widget.report['details'] ?? '';
    final createdAt = widget.report['createdAt'];
    final reporter = widget.report['reporter'];
    final reportedUser = widget.report['reportedUser'];
    final reportedPost = widget.report['reportedPost'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.report, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Report Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection('Report Information', [
                    _buildDetailRow('Type', reportType.toUpperCase()),
                    _buildDetailRow(
                      'Reason',
                      reason
                          .split('_')
                          .map((w) => w[0].toUpperCase() + w.substring(1))
                          .join(' '),
                    ),
                    _buildDetailRow('Status', status.toUpperCase()),
                    _buildDetailRow(
                      'Submitted',
                      createdAt != null
                          ? timeago.format(DateTime.parse(createdAt))
                          : 'Unknown',
                    ),
                  ]),

                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Additional Details', [
                      Text(
                        details,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 16),
                  _buildDetailSection('Reporter', [
                    _buildUserInfo(reporter, showModerationActions: false),
                  ]),

                  const SizedBox(height: 16),
                  if (reportType == 'user')
                    _buildDetailSection('Reported User', [
                      _buildUserInfo(reportedUser, showModerationActions: true),
                    ])
                  else
                    _buildDetailSection('Reported Post', [
                      _buildPostInfo(reportedPost),
                    ]),

                  // Admin notes input
                  if (status == 'pending') ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Admin Notes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      enabled: !_isProcessing,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText: 'Add notes about this report...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Action buttons (only for pending reports)
          if (status == 'pending')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _reviewReport('dismissed', 'none'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isProcessing ? null : () => _showActionDialog(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Take Action'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(Map<String, dynamic>? user,
      {bool showModerationActions = false}) {
    if (user == null) return const Text('User not found');

    final name = user['name'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final avatar = user['avatar'];
    final isSuspended = user['isSuspended'] ?? false;
    final isBanned = user['isBanned'] ?? false;
    final userId = user['_id'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: avatar != null && avatar.toString().isNotEmpty
                  ? UrlUtils.getAvatarImageProvider(avatar)
                  : null,
              child: avatar == null || avatar.toString().isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Show moderation status badges
        if (isBanned || isSuspended) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (isBanned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '🚫 BANNED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              if (isSuspended && !isBanned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '⚠️ SUSPENDED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ],
        // Show unsuspend/unban buttons if this is the reported user
        if (showModerationActions &&
            userId != null &&
            (isSuspended || isBanned)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (isBanned)
                ElevatedButton.icon(
                  onPressed: () => _unbanUser(userId),
                  icon: const Icon(Icons.lock_open, size: 16),
                  label: const Text('Unban User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              if (isSuspended && !isBanned)
                ElevatedButton.icon(
                  onPressed: () => _unsuspendUser(userId),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Unsuspend User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPostInfo(Map<String, dynamic>? post) {
    if (post == null) return const Text('Post not found or deleted');

    final content = post['content'] ?? 'No content';
    final author = post['author'];
    final images = post['images'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (author != null)
          Text(
            'By: ${author['name'] ?? 'Unknown'}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
        if (images != null && (images as List).isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage('${ApiService.baseApi}${images[0]}'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showActionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Take Action'),
        content: const Text(
          'What action would you like to take on this report?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reviewReport('resolved', 'warning');
            },
            child: const Text('Warning'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reviewReport('resolved', 'content_removed');
            },
            child: const Text('Remove Content'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reviewReport('resolved', 'user_suspended');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Suspend User'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reviewReport('resolved', 'user_banned');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Ban User'),
          ),
        ],
      ),
    );
  }
}
