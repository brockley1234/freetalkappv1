import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';

class MusicSelectorBottomSheet extends StatefulWidget {
  final Function(MusicTrack) onTrackSelected;
  final MusicTrack? currentTrack;

  const MusicSelectorBottomSheet({
    super.key,
    required this.onTrackSelected,
    this.currentTrack,
  });

  @override
  State<MusicSelectorBottomSheet> createState() =>
      _MusicSelectorBottomSheetState();
}

class _MusicSelectorBottomSheetState extends State<MusicSelectorBottomSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<MusicTrack> _allTracks = [];
  List<MusicTrack> _filteredTracks = [];
  List<String> _categories = [];
  List<String> _moods = [];

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedMood;
  String? _currentlyPlayingId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBuiltInTracks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadBuiltInTracks() async {
    try {
      final tracks = await MusicService.getBuiltInTracks();
      final categories = await MusicService.getBuiltInCategories();
      final moods = await MusicService.getBuiltInMoods();

      setState(() {
        _allTracks = tracks;
        _filteredTracks = tracks;
        _categories = categories;
        _moods = moods;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterTracks() {
    setState(() {
      _filteredTracks = _allTracks.where((track) {
        bool matchesSearch = _searchQuery.isEmpty ||
            track.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            track.artist.toLowerCase().contains(_searchQuery.toLowerCase());

        bool matchesCategory =
            _selectedCategory == null || track.category == _selectedCategory;

        bool matchesMood = _selectedMood == null || track.mood == _selectedMood;

        return matchesSearch && matchesCategory && matchesMood;
      }).toList();
    });
  }

  Future<void> _playPreview(MusicTrack track) async {
    try {
      if (_currentlyPlayingId == track.id) {
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingId = null;
        });
        return;
      }

      await _audioPlayer.stop();

      // Stream built-in track from API
      final source = await MusicService.audioSourceForBuiltIn(track);
      await _audioPlayer.setAudioSource(source);
      await _audioPlayer.play();

      setState(() {
        _currentlyPlayingId = track.id;
      });

      // Stop after 30s preview
      Future.delayed(const Duration(seconds: 30), () {
        if (_currentlyPlayingId == track.id) {
          setState(() {
            _currentlyPlayingId = null;
          });
          _audioPlayer.stop();
        }
      });
    } catch (e) {
      // Error playing audio preview
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Select Music',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search music...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterTracks();
              },
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Categories'),
              Tab(text: 'Moods'),
            ],
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTrackList(_filteredTracks),
                      _buildCategoryView(),
                      _buildMoodView(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackList(List<MusicTrack> tracks) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isSelected = widget.currentTrack?.id == track.id;
        final isPlaying = _currentlyPlayingId == track.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.music_note,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            title: Text(
              track.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(track.artist),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildChip(track.category, Colors.blue),
                    const SizedBox(width: 4),
                    _buildChip(track.mood, Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      '${track.duration}s',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _playPreview(track),
                  icon: Icon(
                    isPlaying ? Icons.stop : Icons.play_arrow,
                    color: Colors.blue,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    widget.onTrackSelected(track);
                    Navigator.of(context).pop();
                  },
                  icon: Icon(
                    isSelected ? Icons.check_circle : Icons.add_circle_outline,
                    color: isSelected ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final isSelected = _selectedCategory == category;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = isSelected ? null : category;
            });
            _filterTracks();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoodView() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2,
      ),
      itemCount: _moods.length,
      itemBuilder: (context, index) {
        final mood = _moods[index];
        final isSelected = _selectedMood == mood;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedMood = isSelected ? null : mood;
            });
            _filterTracks();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.green : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.green : Colors.grey[300]!,
              ),
            ),
            child: Center(
              child: Text(
                mood,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Helper function to show music selector
void showMusicSelector({
  required BuildContext context,
  required Function(MusicTrack) onTrackSelected,
  MusicTrack? currentTrack,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MusicSelectorBottomSheet(
      onTrackSelected: onTrackSelected,
      currentTrack: currentTrack,
    ),
  );
}
