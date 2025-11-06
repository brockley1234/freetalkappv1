import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/music_service.dart';
import '../services/api_service.dart';
import 'audio_recorder_page.dart';

class MusicSelectionPage extends StatefulWidget {
  const MusicSelectionPage({super.key});

  @override
  State<MusicSelectionPage> createState() => _MusicSelectionPageState();
}

class _MusicSelectionPageState extends State<MusicSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<dynamic> _trendingSounds = [];
  List<dynamic> _mySounds = [];
  List<dynamic> _searchResults = [];
  List<MusicTrack> _builtInTracks = [];

  bool _isLoadingTrending = false;
  bool _isLoadingMy = false;
  bool _isSearching = false;
  bool _isLoadingBuiltIn = false;

  String? _currentPlayingId;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBuiltInTracks();
    _loadTrendingSounds();
    _loadMySounds();

    // Listen to player state
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadTrendingSounds() async {
    setState(() {
      _isLoadingTrending = true;
    });

    try {
      final result = await MusicService.getTrendingSounds();
      if (result['success'] && mounted) {
        setState(() {
          _trendingSounds = result['data']['tracks'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading trending sounds: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTrending = false;
        });
      }
    }
  }

  Future<void> _loadMySounds() async {
    setState(() {
      _isLoadingMy = true;
    });

    try {
      final result = await MusicService.getMySounds();
      if (result['success'] && mounted) {
        setState(() {
          _mySounds = result['data']['tracks'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading my sounds: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMy = false;
        });
      }
    }
  }

  Future<void> _loadBuiltInTracks() async {
    setState(() {
      _isLoadingBuiltIn = true;
    });

    try {
      debugPrint('🎵 Starting to load built-in tracks...');
      final tracks = await MusicService.getBuiltInTracks();
      debugPrint('🎵 Loaded ${tracks.length} built-in tracks');
      if (mounted) {
        setState(() {
          _builtInTracks = tracks;
        });
        debugPrint('🎵 State updated with ${_builtInTracks.length} tracks');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading built-in tracks: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBuiltIn = false;
        });
      }
    }
  }

  Future<void> _searchSounds(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final result = await MusicService.searchSounds(query: query);
      if (result['success'] && mounted) {
        setState(() {
          _searchResults = result['data']['tracks'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error searching sounds: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _playPreview(String trackId, String audioUrl) async {
    try {
      if (_currentPlayingId == trackId && _isPlaying) {
        // Pause if already playing this track
        await _audioPlayer.pause();
        return;
      }

      // Stop current playback
      await _audioPlayer.stop();

      setState(() {
        _currentPlayingId = trackId;
      });

      // Play new track
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing preview: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectSound(Map<String, dynamic> track) {
    // Stop playback
    _audioPlayer.stop();

    // Return selected track to previous screen
    Navigator.pop(context, track);
  }

  Future<void> _playBuiltInPreview(MusicTrack track) async {
    try {
      if (_currentPlayingId == track.id && _isPlaying) {
        // Pause if already playing this track
        await _audioPlayer.pause();
        return;
      }

      // Stop current playback
      await _audioPlayer.stop();

      setState(() {
        _currentPlayingId = track.id;
      });

      debugPrint('🎵 Attempting to play: ${track.title}');
      debugPrint('🎵 Filename: ${track.filename}');

      // Stream audio from API with auth headers
      final source = await MusicService.audioSourceForBuiltIn(track);
      debugPrint('🎵 Audio source created, setting source...');

      await _audioPlayer.setAudioSource(source);
      debugPrint('🎵 Audio source set, starting playback...');

      await _audioPlayer.play();
      debugPrint('🎵 Playback started successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error playing built-in preview: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      setState(() {
        _currentPlayingId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to play audio: (${e.runtimeType}) ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _selectBuiltInSound(MusicTrack track) {
    // Stop playback
    _audioPlayer.stop();

    // Convert MusicTrack to Map format expected by the video upload
    // Use server URL for built-in tracks instead of assets
    final trackData = {
      '_id': track.id,
      'title': track.title,
      'artist': track.artist,
      'duration': track.duration,
      'category': track.category,
      'mood': track.mood,
      'genre': track.genre,
      'license': track.license,
      'description': track.description,
      'isBuiltIn': true, // Flag to indicate this is a built-in track
      'filename': track.filename,
      'url':
          '${ApiService.baseApi}/api/music/built-in/stream/${Uri.encodeComponent(track.filename)}', // Server URL for streaming
      'source': 'built-in',
    };

    // Return selected track to previous screen
    Navigator.pop(context, trackData);
  }

  Widget _buildSoundTile(Map<String, dynamic> track) {
    final trackId = track['_id'] ?? '';
    final title = track['title'] ?? 'Unknown';
    final artist = track['artist'] ?? 'Unknown Artist';
    final usageCount = track['usageCount'] ?? 0;
    final duration = track['duration'] ?? 0;
    final audioUrl = track['url'] ?? '';

    final isCurrentlyPlaying = _currentPlayingId == trackId && _isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.purple.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCurrentlyPlaying ? Icons.pause : Icons.music_note,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              artist,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.play_circle_outline,
                    size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${usageCount.toString()} videos',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${duration}s',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
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
              icon: Icon(
                isCurrentlyPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Colors.blue,
                size: 32,
              ),
              onPressed: () => _playPreview(trackId, audioUrl),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _selectSound(track),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInSoundTile(MusicTrack track) {
    final isCurrentlyPlaying = _currentPlayingId == track.id && _isPlaying;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade400, Colors.teal.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isCurrentlyPlaying ? Icons.pause : Icons.music_note,
            color: Colors.white,
            size: 28,
          ),
        ),
        title: Text(
          track.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              track.artist,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildChip(track.category, Colors.blue),
                const SizedBox(width: 8),
                _buildChip(track.mood, Colors.green),
                const SizedBox(width: 8),
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${track.duration}s',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
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
              icon: Icon(
                isCurrentlyPlaying ? Icons.pause_circle : Icons.play_circle,
                color: Colors.green,
                size: 32,
              ),
              onPressed: () => _playBuiltInPreview(track),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _selectBuiltInSound(track),
            ),
          ],
        ),
      ),
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

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search sounds...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                _searchSounds(value);
              } else {
                setState(() {
                  _searchResults = [];
                });
              }
            },
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.music_note,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Search for sounds'
                                : 'No sounds found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return _buildSoundTile(_searchResults[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBuiltInTab() {
    if (_isLoadingBuiltIn) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_builtInTracks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No built-in tracks available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading status: $_isLoadingBuiltIn',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Text(
                'Track count: ${_builtInTracks.length}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              if (MusicService.lastError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    'Error Details:\n${MusicService.lastError}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBuiltInTracks,
                child: const Text('Retry Loading Tracks'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBuiltInTracks,
      child: ListView.builder(
        itemCount: _builtInTracks.length,
        itemBuilder: (context, index) {
          return _buildBuiltInSoundTile(_builtInTracks[index]);
        },
      ),
    );
  }

  Widget _buildTrendingTab() {
    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_trendingSounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No trending sounds yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrendingSounds,
      child: ListView.builder(
        itemCount: _trendingSounds.length,
        itemBuilder: (context, index) {
          return _buildSoundTile(_trendingSounds[index]);
        },
      ),
    );
  }

  Widget _buildMySoundsTab() {
    if (_isLoadingMy) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mySounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No sounds uploaded yet',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                // Navigate to audio recorder page
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AudioRecorderPage(),
                  ),
                );

                // Reload sounds if a new one was uploaded
                if (result == true && mounted) {
                  _loadMySounds();
                }
              },
              icon: const Icon(Icons.mic),
              label: const Text('Record Sound'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMySounds,
      child: ListView.builder(
        itemCount: _mySounds.length,
        itemBuilder: (context, index) {
          return _buildSoundTile(_mySounds[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Select Sound'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(icon: Icon(Icons.music_note), text: 'Built-in'),
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trending'),
            Tab(icon: Icon(Icons.library_music), text: 'My Sounds'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBuiltInTab(),
          _buildSearchTab(),
          _buildTrendingTab(),
          _buildMySoundsTab(),
        ],
      ),
    );
  }
}
