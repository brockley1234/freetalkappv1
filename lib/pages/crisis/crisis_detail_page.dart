import 'package:flutter/material.dart';
import '../../services/crisis_service.dart';
import '../../utils/time_utils.dart';
import '../../utils/url_utils.dart';

class CrisisDetailPage extends StatefulWidget {
  final String crisisId;

  const CrisisDetailPage({super.key, required this.crisisId});

  @override
  State<CrisisDetailPage> createState() => _CrisisDetailPageState();
}

class _CrisisDetailPageState extends State<CrisisDetailPage>
    with SingleTickerProviderStateMixin {
  late CrisisService _crisisService;
  CrisisResponse? _crisis;
  bool _isLoading = true;
  final _updateController = TextEditingController();
  final _scrollController = ScrollController();
  late TabController _tabController;

  // Store the listener function so we can remove it properly
  late Function(Map<String, dynamic>) _crisisListener;

  @override
  void initState() {
    super.initState();
    _crisisService = CrisisService();
    _tabController = TabController(length: 4, vsync: this);
    _loadCrisisData();
    _setupRealtimeListener();
  }

  Future<void> _loadCrisisData() async {
    setState(() => _isLoading = true);
    final crisis = await _crisisService.fetchCrisisById(widget.crisisId);
    if (mounted) {
      setState(() {
        _crisis = crisis;
        _isLoading = false;
      });
    }

    // Notify viewing
    _crisisService.notifyViewing(widget.crisisId);
  }

  void _setupRealtimeListener() {
    _crisisListener = (data) {
      // Reload crisis data when updates come in
      _loadCrisisData();
    };
    _crisisService.addCrisisListener(widget.crisisId, _crisisListener);
  }

  @override
  void dispose() {
    _updateController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    // Remove listener when leaving
    _crisisService.removeCrisisListener(widget.crisisId, _crisisListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Crisis Details'),
          backgroundColor: Colors.red.shade700,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_crisis == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Crisis Details'),
          backgroundColor: Colors.red.shade700,
        ),
        body: const Center(
          child: Text('Crisis not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crisis Details'),
        backgroundColor: Colors.red.shade700,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info, size: 18)),
            Tab(text: 'Updates', icon: Icon(Icons.update, size: 18)),
            Tab(text: 'Helpers', icon: Icon(Icons.people, size: 18)),
            Tab(text: 'Resources', icon: Icon(Icons.help, size: 18)),
          ],
        ),
        actions: [
          if (_crisis!.status == 'active' || _crisis!.status == 'in_progress')
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showOptionsMenu,
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildUpdatesTab(),
          _buildHelpersTab(),
          _buildResourcesTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildUserInfo(),
          const SizedBox(height: 16),
          _buildDescriptionCard(),
          if (_crisis!.location?['address'] != null) ...[
            const SizedBox(height: 16),
            _buildLocationCard(),
          ],
          if (_crisis!.contactPhone != null) ...[
            const SizedBox(height: 16),
            _buildContactCard(),
          ],
          const SizedBox(height: 16),
          _buildStatsCard(),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildSeverityIcon(_crisis!.severity),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _crisis!.crisisType.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildStatusBadge(_crisis!.status),
                      const SizedBox(width: 8),
                      Text(
                        TimeUtils.formatMessageTimestamp(
                            _crisis!.createdAt.toIso8601String()),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityIcon(String severity) {
    IconData icon;
    Color color;

    switch (severity) {
      case 'critical':
        icon = Icons.error;
        color = Colors.red.shade700;
        break;
      case 'high':
        icon = Icons.warning;
        color = Colors.orange.shade700;
        break;
      case 'medium':
        icon = Icons.info;
        color = Colors.yellow.shade700;
        break;
      default:
        icon = Icons.info_outline;
        color = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.red;
        break;
      case 'in_progress':
        color = Colors.orange;
        break;
      case 'resolved':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: _crisis!.isAnonymous || _crisis!.userProfilePicture == null
            ? CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Icon(Icons.person, color: Colors.grey.shade600),
              )
            : CircleAvatar(
                backgroundImage: UrlUtils.getAvatarImageProvider(
                    _crisis!.userProfilePicture),
              ),
        title: Text(
          _crisis!.isAnonymous ? 'Anonymous User' : _crisis!.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Visibility: ${_crisis!.visibility.replaceAll('_', ' ')}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _crisis!.description,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.location_on, color: Colors.red.shade700),
        title: const Text('Location',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_crisis!.location!['address']),
      ),
    );
  }

  Widget _buildContactCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.phone, color: Colors.green.shade700),
        title: const Text('Contact',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_crisis!.contactPhone!),
        trailing: IconButton(
          icon: const Icon(Icons.call),
          onPressed: () {
            // Add call functionality
          },
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.people,
                  '${_crisis!.helpers.length}',
                  'Helpers',
                  Colors.blue,
                ),
                _buildStatItem(
                  Icons.verified_user,
                  '${_crisis!.safetyChecks.length}',
                  'Safety Checks',
                  Colors.green,
                ),
                _buildStatItem(
                  Icons.update,
                  '${_crisis!.updates.length}',
                  'Updates',
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdatesTab() {
    if (_crisis!.updates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.update, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No updates yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _crisis!.updates.length,
      itemBuilder: (context, index) {
        final update = _crisis!.updates[index];
        return _buildUpdateCard(update);
      },
    );
  }

  Widget _buildUpdateCard(Update update) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                update.userProfilePicture != null
                    ? CircleAvatar(
                        backgroundImage:
                            NetworkImage(update.userProfilePicture!),
                        radius: 16,
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        radius: 16,
                        child: Icon(Icons.person,
                            size: 18, color: Colors.grey.shade600),
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        update.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        TimeUtils.formatMessageTimestamp(
                            update.timestamp.toIso8601String()),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(update.message),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpersTab() {
    if (_crisis!.helpers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No helpers yet'),
            const SizedBox(height: 8),
            const Text('Be the first to offer help!'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _crisis!.helpers.length,
      itemBuilder: (context, index) {
        final helper = _crisis!.helpers[index];
        return _buildHelperCard(helper);
      },
    );
  }

  Widget _buildHelperCard(Helper helper) {
    Color statusColor;
    switch (helper.status) {
      case 'helping':
        statusColor = Colors.green;
        break;
      case 'accepted':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: helper.userProfilePicture != null
            ? CircleAvatar(
                backgroundImage:
                    UrlUtils.getAvatarImageProvider(helper.userProfilePicture),
              )
            : CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Icon(Icons.person, color: Colors.grey.shade600),
              ),
        title: Text(
          helper.userName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(helper.message),
            const SizedBox(height: 4),
            Text(
              TimeUtils.formatMessageTimestamp(
                  helper.respondedAt.toIso8601String()),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            helper.status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildResourcesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _showEmergencyResources,
            icon: const Icon(Icons.emergency_share),
            label: const Text('View Emergency Resources'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 24),
          if (_crisis!.resources.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(Icons.help_outline,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No resources shared yet'),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _crisis!.resources.length,
              itemBuilder: (context, index) {
                final resource = _crisis!.resources[index];
                return _buildResourceCard(resource);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(Resource resource) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(Icons.health_and_safety, color: Colors.blue.shade700),
        title: Text(
          resource.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(resource.type.replaceAll('_', ' ')),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        resource.contact,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                if (resource.description != null) ...[
                  const SizedBox(height: 8),
                  Text(resource.description!),
                ],
                const SizedBox(height: 8),
                Text(
                  'Provided by ${resource.providedByName}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActions() {
    if (_crisis!.status == 'resolved' || _crisis!.status == 'closed') {
      return null;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _offerHelp,
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Offer Help'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _performSafetyCheck,
              icon: const Icon(Icons.health_and_safety),
              label: const Text('Safety Check'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_comment),
              title: const Text('Add Update'),
              onTap: () {
                Navigator.pop(context);
                _addUpdate();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Add Resource'),
              onTap: () {
                Navigator.pop(context);
                _addResource();
              },
            ),
            ListTile(
              leading: const Icon(Icons.emergency),
              title: const Text('Send Emergency Broadcast'),
              onTap: () {
                Navigator.pop(context);
                _sendEmergencyBroadcast();
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Resolve Crisis'),
              onTap: () {
                Navigator.pop(context);
                _resolveCrisis();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _offerHelp() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _HelpOfferDialog(),
    );

    if (message != null && mounted) {
      final success =
          await _crisisService.offerHelp(widget.crisisId, message: message);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Help offer sent')),
        );
        _loadCrisisData();
      }
    }
  }

  Future<void> _performSafetyCheck() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _SafetyCheckDialog(),
    );

    if (result != null && mounted) {
      final success = await _crisisService.performSafetyCheck(
        widget.crisisId,
        result['status']!,
        message: result['message'],
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Safety check recorded')),
        );
        _loadCrisisData();
      }
    }
  }

  Future<void> _addUpdate() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _AddUpdateDialog(),
    );

    if (message != null && message.trim().isNotEmpty && mounted) {
      _crisisService.sendUpdateRealtime(widget.crisisId, message.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update sent')),
        );
      }
    }
  }

  Future<void> _addResource() async {
    // Add resource dialog implementation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add resource feature coming soon')),
      );
    }
  }

  Future<void> _sendEmergencyBroadcast() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Emergency Broadcast?'),
        content: const Text(
          'This will send a high-priority alert to all available helpers. Only use in critical situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _crisisService.sendEmergencyBroadcast(widget.crisisId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency broadcast sent'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resolveCrisis() async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) => _ResolveCrisisDialog(),
    );

    if (message != null && mounted) {
      final success =
          await _crisisService.resolveCrisis(widget.crisisId, message: message);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crisis resolved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _showEmergencyResources() async {
    if (!mounted) return;
    final resources =
        await _crisisService.getEmergencyResources(_crisis!.crisisType);

    if (resources != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => _EmergencyResourcesDialog(resources: resources),
      );
    }
  }
}

// Helper dialogs
class _HelpOfferDialog extends StatefulWidget {
  @override
  State<_HelpOfferDialog> createState() => _HelpOfferDialogState();
}

class _HelpOfferDialogState extends State<_HelpOfferDialog> {
  final _controller = TextEditingController(text: 'I am here to help');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Offer Help'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter your message...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _SafetyCheckDialog extends StatefulWidget {
  @override
  State<_SafetyCheckDialog> createState() => _SafetyCheckDialogState();
}

class _SafetyCheckDialogState extends State<_SafetyCheckDialog> {
  String _status = 'safe';
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Safety Check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'safe', child: Text('Safe')),
              DropdownMenuItem(value: 'needs_help', child: Text('Needs Help')),
              DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
            ],
            onChanged: (value) => setState(() => _status = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Additional notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'status': _status,
            'message': _controller.text,
          }),
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class _AddUpdateDialog extends StatefulWidget {
  @override
  State<_AddUpdateDialog> createState() => _AddUpdateDialogState();
}

class _AddUpdateDialogState extends State<_AddUpdateDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Update'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        maxLength: 500,
        decoration: const InputDecoration(
          hintText: 'Share an update...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _ResolveCrisisDialog extends StatefulWidget {
  @override
  State<_ResolveCrisisDialog> createState() => _ResolveCrisisDialogState();
}

class _ResolveCrisisDialogState extends State<_ResolveCrisisDialog> {
  final _controller =
      TextEditingController(text: 'Crisis resolved, thank you for your help');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve Crisis'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Resolution message...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Resolve'),
        ),
      ],
    );
  }
}

class _EmergencyResourcesDialog extends StatelessWidget {
  final Map<String, dynamic> resources;

  const _EmergencyResourcesDialog({required this.resources});

  @override
  Widget build(BuildContext context) {
    final resourceList = resources['resources'] as List? ?? [];

    return AlertDialog(
      title: const Text('Emergency Resources'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: resourceList.length,
          itemBuilder: (context, index) {
            final resource = resourceList[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.phone, color: Colors.red),
                title: Text(resource['name']),
                subtitle: Text(resource['description']),
                trailing: Text(
                  resource['contact'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
