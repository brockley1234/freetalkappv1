import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  State<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  final CacheService _cacheService = CacheService();
  Map<String, dynamic>? _cacheStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheStats();
  }

  Future<void> _loadCacheStats() async {
    setState(() {
      _isLoading = true;
    });

    final stats = await _cacheService.getCacheStats();

    setState(() {
      _cacheStats = stats;
      _isLoading = false;
    });
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Cache'),
        content: const Text(
          'This will clear all cached data including posts, stories, and user profiles. You\'ll need to reload data from the server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cacheService.clearAllCache();
      await _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _clearPostsCache() async {
    await _cacheService.clearPostsCache();
    await _loadCacheStats();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Posts cache cleared'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearOfflinePosts() async {
    final offlinePosts = await _cacheService.getOfflinePosts();

    if (offlinePosts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No offline posts to clear'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Offline Posts'),
        content: Text(
          'This will remove ${offlinePosts.length} saved post(s) for offline viewing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cacheService.clearOfflinePosts();
      await _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline posts cleared'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Settings'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCacheStats,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Cache stats card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storage,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Cache Statistics',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildStatRow(
                            'Total Size',
                            '${_cacheStats?['sizeInKB'] ?? '0.00'} KB',
                          ),
                          _buildStatRow(
                            'Items Cached',
                            '${_cacheStats?['itemCount'] ?? 0}',
                          ),
                          if (double.parse(_cacheStats?['sizeInMB'] ?? '0.00') >
                              0)
                            _buildStatRow(
                              'Size (MB)',
                              '${_cacheStats?['sizeInMB'] ?? '0.00'} MB',
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cache actions card
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            Icons.delete_sweep,
                            color: Colors.orange.shade700,
                          ),
                          title: const Text('Clear Posts Cache'),
                          subtitle: const Text(
                            'Remove cached posts from feed',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _clearPostsCache,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.offline_pin_outlined,
                            color: Colors.blue.shade700,
                          ),
                          title: const Text('Clear Offline Posts'),
                          subtitle: const Text(
                            'Remove posts saved for offline viewing',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _clearOfflinePosts,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            Icons.delete_forever,
                            color: Colors.red.shade700,
                          ),
                          title: const Text('Clear All Cache'),
                          subtitle: const Text(
                            'Remove all cached data',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _clearAllCache,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Cache helps improve app performance by storing data locally. Clear it if you\'re experiencing issues or want to free up space.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
