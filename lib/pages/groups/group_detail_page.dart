import 'package:flutter/material.dart';
import '../../services/group_service.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _group;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await GroupService.getGroup(widget.groupId);
      if (res['success'] == true) {
        setState(() { _group = Map<String, dynamic>.from(res['data']['group'] ?? {}); _loading = false; });
      } else {
        setState(() { _error = res['message'] ?? 'Failed to load group'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_group?['name'] ?? 'Group')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(_group?['name'] ?? '', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      if ((_group?['description'] ?? '').toString().isNotEmpty)
                        Text(_group?['description'] ?? ''),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Chip(label: Text((_group?['privacy'] ?? 'public').toString())),
                          const SizedBox(width: 8),
                          Chip(label: Text('${_group?['membersCount'] ?? 0} members')),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}


