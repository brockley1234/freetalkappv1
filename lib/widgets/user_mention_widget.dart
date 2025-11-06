import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../utils/url_utils.dart';

class UserMentionWidget extends StatefulWidget {
  final Function(Map<String, dynamic> user) onUserSelected;
  final String searchQuery;

  const UserMentionWidget({
    super.key,
    required this.onUserSelected,
    required this.searchQuery,
  });

  @override
  State<UserMentionWidget> createState() => _UserMentionWidgetState();
}

class _UserMentionWidgetState extends State<UserMentionWidget> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchUsers(widget.searchQuery);
  }

  @override
  void didUpdateWidget(UserMentionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      // Debounce search to avoid too many API calls
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _searchUsers(widget.searchQuery);
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _users = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.searchUsers(query: query);
      if (result['success'] == true && mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(
            result['data']['users'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No users found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user['avatar'] != null
                  ? UrlUtils.getAvatarImageProvider(user['avatar'])
                  : null,
              child: user['avatar'] == null
                  ? Text(
                      (user['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            title: Text(
              user['name'] ?? 'Unknown',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: user['email'] != null
                ? Text(
                    user['email'],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                : null,
            onTap: () {
              widget.onUserSelected(user);
            },
          );
        },
      ),
    );
  }
}

class TaggedUserChip extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onDeleted;

  const TaggedUserChip({
    super.key,
    required this.user,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundImage: user['avatar'] != null
            ? UrlUtils.getAvatarImageProvider(user['avatar'])
            : null,
        child: user['avatar'] == null
            ? Text(
                (user['name'] ?? 'U')[0].toUpperCase(),
                style: const TextStyle(fontSize: 12),
              )
            : null,
      ),
      label: Text(user['name'] ?? 'Unknown'),
      deleteIcon: const Icon(Icons.close, size: 18),
      onDeleted: onDeleted,
      backgroundColor: Colors.blue.shade50,
      deleteIconColor: Colors.blue.shade700,
      labelStyle: TextStyle(
        color: Colors.blue.shade700,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
