import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
// import 'package:web/web.dart' as web;

class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String filename;
  final int duration;
  final String category;
  final String mood;
  final String genre;
  final String license;
  final String description;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.filename,
    required this.duration,
    required this.category,
    required this.mood,
    required this.genre,
    required this.license,
    required this.description,
  });

  factory MusicTrack.fromJson(Map<String, dynamic> json) {
    return MusicTrack(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      filename: json['filename'],
      duration: json['duration'],
      category: json['category'],
      mood: json['mood'],
      genre: json['genre'],
      license: json['license'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'filename': filename,
      'duration': duration,
      'category': category,
      'mood': mood,
      'genre': genre,
      'license': license,
      'description': description,
    };
  }

  String get streamUrl => MusicService.buildBuiltInStreamUrl(filename);
}

class MusicService {
  static String get baseUrl => ApiService.baseUrl;
  static List<MusicTrack>? _builtInTracks;
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Return only Authorization header when needed (for media requests)
  static Future<Map<String, String>> getAuthHeaderOnly() async {
    final token = await _getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token'};
  }

  // Load built-in music tracks from assets
  static Future<List<MusicTrack>> getBuiltInTracks() async {
    _lastError = null;

    if (_builtInTracks != null) {
      return _builtInTracks!;
    }

    try {
      String jsonData = '';

      // Load from assets (works on all platforms)
      jsonData = await rootBundle.loadString('assets/music/track_library.json');

      final List<dynamic> tracksJson = json.decode(jsonData);
      _builtInTracks = tracksJson
          .map((trackJson) => MusicTrack.fromJson(trackJson))
          .toList();
      return _builtInTracks!;
    } catch (e, stackTrace) {
      _lastError =
          'Error: $e\nStack: ${stackTrace.toString().split('\n').take(3).join('\n')}';
      return [];
    }
  }

  // Get built-in tracks by category
  static Future<List<MusicTrack>> getBuiltInTracksByCategory(
      String category) async {
    final tracks = await getBuiltInTracks();
    return tracks
        .where(
            (track) => track.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  // Get built-in tracks by mood
  static Future<List<MusicTrack>> getBuiltInTracksByMood(String mood) async {
    final tracks = await getBuiltInTracks();
    return tracks
        .where((track) => track.mood.toLowerCase() == mood.toLowerCase())
        .toList();
  }

  // Search built-in tracks
  static Future<List<MusicTrack>> searchBuiltInTracks(String query) async {
    final tracks = await getBuiltInTracks();
    final lowercaseQuery = query.toLowerCase();

    return tracks.where((track) {
      return track.title.toLowerCase().contains(lowercaseQuery) ||
          track.artist.toLowerCase().contains(lowercaseQuery) ||
          track.category.toLowerCase().contains(lowercaseQuery) ||
          track.mood.toLowerCase().contains(lowercaseQuery) ||
          track.genre.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  // Get all available categories from built-in tracks
  static Future<List<String>> getBuiltInCategories() async {
    final tracks = await getBuiltInTracks();
    final categories = tracks.map((track) => track.category).toSet().toList();
    categories.sort();
    return categories;
  }

  // Get all available moods from built-in tracks
  static Future<List<String>> getBuiltInMoods() async {
    final tracks = await getBuiltInTracks();
    final moods = tracks.map((track) => track.mood).toSet().toList();
    moods.sort();
    return moods;
  }

  // Get built-in track by ID
  static Future<MusicTrack?> getBuiltInTrackById(String trackId) async {
    final tracks = await getBuiltInTracks();
    try {
      return tracks.firstWhere((track) => track.id == trackId);
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, String>> _getHeaders(
      {bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Get trending sounds/music
  static Future<Map<String, dynamic>> getTrendingSounds({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music/trending?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'data': {'tracks': []}};
      }
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching trending sounds: $e');
      return {'success': false, 'message': 'Failed to fetch trending sounds', 'data': {'tracks': []}};
    }
  }

  // Get popular sounds/music
  static Future<Map<String, dynamic>> getPopularSounds({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    try {
      String url = '$baseUrl/music/popular?page=$page&limit=$limit';
      if (category != null && category.isNotEmpty) {
        url += '&category=$category';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'data': {'tracks': []}};
      }
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching popular sounds: $e');
      return {'success': false, 'message': 'Failed to fetch popular sounds', 'data': {'tracks': []}};
    }
  }

  // Get user's uploaded sounds
  static Future<Map<String, dynamic>> getMySounds({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music/my-sounds?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );

      if (response.body.isEmpty) {
        return {'success': false, 'data': {'tracks': []}};
      }
      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching my sounds: $e');
      return {'success': false, 'message': 'Failed to fetch your sounds', 'data': {'tracks': []}};
    }
  }

  // Search for sounds/music
  static Future<Map<String, dynamic>> searchSounds({
    required String query,
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      String url =
          '$baseUrl/music/search?q=$encodedQuery&page=$page&limit=$limit';

      if (category != null && category.isNotEmpty) {
        url += '&category=$category';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error searching sounds: $e');
      return {'success': false, 'message': 'Failed to search sounds'};
    }
  }

  // Get sound categories
  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music/categories'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      return {'success': false, 'message': 'Failed to fetch categories'};
    }
  }

  // Get single music track
  static Future<Map<String, dynamic>> getMusicTrack(String trackId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music/$trackId'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching music track: $e');
      return {'success': false, 'message': 'Failed to fetch music track'};
    }
  }

  // Get videos using a specific sound
  static Future<Map<String, dynamic>> getVideosUsingSound({
    required String trackId,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/music/$trackId/videos?page=$page&limit=$limit'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error fetching videos using sound: $e');
      return {'success': false, 'message': 'Failed to fetch videos'};
    }
  }

  // Upload user-created sound/audio
  static Future<Map<String, dynamic>> uploadSound({
    required File? audioFile,
    required String title,
    String? artist,
    required double duration,
    String? category,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Authentication required'};
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/music/upload'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $token';

      // Add audio file
      if (audioFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'audio',
            audioFile.path,
            contentType: MediaType('audio', 'mpeg'),
          ),
        );
      }

      // Add fields
      request.fields['title'] = title;
      if (artist != null && artist.isNotEmpty) {
        request.fields['artist'] = artist;
      }
      request.fields['duration'] = duration.toString();
      if (category != null && category.isNotEmpty) {
        request.fields['category'] = category;
      }
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = json.encode(tags);
      }

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error uploading sound: $e');
      return {'success': false, 'message': 'Failed to upload sound: $e'};
    }
  }

  // Delete user's uploaded sound
  static Future<Map<String, dynamic>> deleteSound(String trackId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/music/$trackId'),
        headers: await _getHeaders(),
      );

      return json.decode(response.body);
    } catch (e) {
      debugPrint('Error deleting sound: $e');
      return {'success': false, 'message': 'Failed to delete sound'};
    }
  }

  static String buildBuiltInStreamUrl(String filename) {
    // e.g., https://api.example.com/api/music/built-in/stream/<encoded-filename>
    final encoded = Uri.encodeComponent(filename);
    return '$baseUrl/music/built-in/stream/$encoded';
  }

  // Get a signed/authorized URL for just_audio (adds Bearer token via headers workaround)
  static Future<AudioSource> audioSourceForBuiltIn(MusicTrack track) async {
    final url = buildBuiltInStreamUrl(track.filename);
    final token = await _getToken();

    debugPrint('🎵 Building audio source for: ${track.title}');
    debugPrint('🎵 Stream URL: $url');
    debugPrint('🎵 Base URL: $baseUrl');
    debugPrint('🎵 Has token: ${token != null}');

    // For just_audio, use the UriAudioSource with headers
    return AudioSource.uri(
      Uri.parse(url),
      headers: token != null ? {'Authorization': 'Bearer $token'} : null,
    );
  }
}
