import 'package:flutter/material.dart';
import '../services/poke_service.dart';
import '../utils/time_utils.dart';
import '../utils/url_utils.dart';
import '../widgets/poke_dialog.dart';
import 'user_profile_page.dart';

class PokesPage extends StatefulWidget {
  const PokesPage({super.key});

  @override
  State<PokesPage> createState() => _PokesPageState();
}

class _PokesPageState extends State<PokesPage> {
  final PokeService _pokeService = PokeService();

  bool _isLoading = true;
  List<dynamic> _pokes = [];
  int _currentPage = 1;
  bool _hasMorePokes = true;
  int _unseenCount = 0;

  // Poke type configurations (DRY principle)
  static const Map<String, Map<String, dynamic>> _pokeTypeConfig = {
    'slap': {'emoji': '👋💥', 'label': 'Slapped you!', 'color': 0xFFFF9800},
    'kiss': {'emoji': '💋😘', 'label': 'Sent you a kiss!', 'color': 0xFFE91E63},
    'hug': {'emoji': '🤗💕', 'label': 'Hugged you!', 'color': 0xFF9C27B0},
    'wave': {'emoji': '👋😊', 'label': 'Waved at you!', 'color': 0xFF2196F3},
  };

  @override
  void initState() {
    super.initState();
    _loadPokes();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPokes({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMorePokes = true;
        _pokes = [];
        _isLoading = true;
      });
    }

    if (!_hasMorePokes) {
      return;
    }

    // Prevent multiple simultaneous loads (except on refresh)
    if (_isLoading && !refresh && _pokes.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _pokeService.getPokes(
        page: _currentPage,
        limit: 20,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>;
        final newPokes = data['pokes'] as List<dynamic>;
        final unseenCount = data['unseenCount'] as int;

        setState(() {
          if (refresh) {
            _pokes = newPokes;
          } else {
            _pokes.addAll(newPokes);
          }
          _unseenCount = unseenCount;
          _currentPage++;
          _hasMorePokes = newPokes.length >= 20;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to load pokes: ${response['message'] ?? 'Unknown error'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load pokes: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsSeen(String pokeId) async {
    try {
      await _pokeService.markPokeAsSeen(pokeId);
      if (!mounted) return;

      setState(() {
        final index = _pokes.indexWhere((p) => p['_id'] == pokeId);
        if (index != -1) {
          _pokes[index]['seen'] = true;
          if (_unseenCount > 0) _unseenCount--;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking poke as seen: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _deletePoke(String pokeId) async {
    try {
      await _pokeService.deletePoke(pokeId);
      if (!mounted) return;

      setState(() {
        _pokes.removeWhere((p) => p['_id'] == pokeId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Poke deleted'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete poke: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pokes'),
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_unseenCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔔',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_unseenCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadPokes(refresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _pokes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_pokes.isEmpty) {
      return _buildEmptyState();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          _loadPokes();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _pokes.length + (_hasMorePokes ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _pokes.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildPokeCard(_pokes[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pan_tool,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No pokes yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'When someone pokes you, it will appear here.\nPoke your friends to get them started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.people),
              label: const Text('Find Friends'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPokeCard(Map<String, dynamic> poke) {
    final sender = poke['sender'] as Map<String, dynamic>?;
    final senderName = sender?['name'] ?? 'Someone';
    final senderAvatar = sender?['avatar'];
    final senderId = sender?['_id'];
    final pokeType = poke['pokeType'] as String? ?? 'wave';
    final seen = poke['seen'] as bool? ?? false;
    final pokeId = poke['_id'] as String;
    final createdAt = poke['createdAt'] as String?;

    final config = _pokeTypeConfig[pokeType] ?? _pokeTypeConfig['wave']!;
    final emoji = config['emoji'] as String;
    final label = config['label'] as String;
    final colorValue = config['color'] as int;
    final color = Color(colorValue);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: seen ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: seen ? null : color.withValues(alpha: 0.05),
        child: InkWell(
          onTap: () {
            if (!seen) {
              _markAsSeen(pokeId);
            }
            if (senderId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(userId: senderId),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatarSection(color, senderAvatar, senderName),
                const SizedBox(width: 16),
                _buildContentSection(
                  senderName,
                  emoji,
                  label,
                  createdAt,
                  color,
                  seen,
                ),
                _buildMenuSection(pokeId, senderId, senderName),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection(
    Color color,
    String? senderAvatar,
    String senderName,
  ) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: color.withValues(alpha: 0.2),
      backgroundImage: senderAvatar != null
          ? UrlUtils.getAvatarImageProvider(senderAvatar)
          : null,
      child: senderAvatar == null
          ? Text(
              senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          : null,
    );
  }

  Widget _buildContentSection(
    String senderName,
    String emoji,
    String label,
    String? createdAt,
    Color color,
    bool seen,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: seen ? FontWeight.w500 : FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!seen)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              TimeUtils.formatMessageTimestamp(createdAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection(
    String pokeId,
    String? senderId,
    String senderName,
  ) {
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'poke_back',
          enabled: senderId != null,
          child: const Row(
            children: [
              Icon(Icons.pan_tool),
              SizedBox(width: 12),
              Text('Poke back'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'poke_back' && senderId != null) {
          showPokeDialog(context, senderId, senderName);
        } else if (value == 'delete') {
          await _deletePoke(pokeId);
        }
      },
    );
  }
}
