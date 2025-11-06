import 'package:flutter/material.dart';
import '../../services/group_service.dart';

class GroupsListPage extends StatefulWidget {
  const GroupsListPage({super.key});

  @override
  State<GroupsListPage> createState() => _GroupsListPageState();
}

class _GroupsListPageState extends State<GroupsListPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String q = ''}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await GroupService.listGroups(q: q);
      if (res['success'] == true) {
        final items = List<Map<String, dynamic>>.from(res['data']['items'] ?? []);
        setState(() { _items = items; _loading = false; });
      } else {
        setState(() { _error = res['message'] ?? 'Failed to load groups'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _join(String id) async {
    final res = await GroupService.joinGroup(id);
    final ok = res['success'] == true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (res['message'] ?? 'Joined') : (res['message'] ?? 'Failed')),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) {
      _load(q: _search.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onSubmitted: (v) => _load(q: v.trim()),
              decoration: InputDecoration(
                hintText: 'Search groups',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _load(q: _search.text.trim()),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final g = _items[i];
                          final joined = g['isMember'] == true;
                          return ListTile(
                            title: Text(g['name'] ?? ''),
                            subtitle: Text((g['description'] ?? '').toString()),
                            trailing: joined
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : TextButton(
                                    onPressed: () => _join(g['_id']),
                                    child: Text(g['privacy'] == 'private' ? 'Request' : 'Join'),
                                  ),
                            onTap: () async {
                              await Navigator.of(context).pushNamed('/group', arguments: g['_id']);
                              if (!mounted) return;
                              _load(q: _search.text.trim());
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showDialog<String>(context: context, builder: (ctx) {
            final c = TextEditingController();
            return AlertDialog(
              title: const Text('Create group'),
              content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Group name')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
              ],
            );
          });
          if (name != null && name.isNotEmpty) {
            final res = await GroupService.createGroup(name: name);
            final ok = res['success'] == true;
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ok ? 'Group created' : (res['message'] ?? 'Failed')),
              backgroundColor: ok ? Colors.green : Colors.red,
            ));
            if (ok) _load();
          }
        },
        icon: const Icon(Icons.group_add),
        label: const Text('New Group'),
      ),
    );
  }
}


