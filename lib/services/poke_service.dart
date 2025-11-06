import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'http_service.dart';

class PokeService {
  static final PokeService _instance = PokeService._internal();
  factory PokeService() => _instance;
  PokeService._internal();

  final HttpService _httpService = HttpService();

  /// Send a poke to a user
  /// [recipientId] - The ID of the user to poke
  /// [pokeType] - Type of poke: 'slap', 'kiss', 'hug', 'wave'
  Future<Map<String, dynamic>> sendPoke(
    String recipientId,
    String pokeType,
  ) async {
    try {
      debugPrint('🤚 ==========================================');
      debugPrint('🤚 Sending $pokeType to user $recipientId');
      debugPrint('🤚 URL: /pokes');
      debugPrint('🤚 Data: {recipientId: $recipientId, pokeType: $pokeType}');

      final response = await _httpService.post(
        '/pokes',
        data: {'recipientId': recipientId, 'pokeType': pokeType},
      );

      debugPrint('🤚 ✅ Response received');
      debugPrint('🤚 Status: ${response.statusCode}');
      debugPrint('🤚 Data: ${response.data}');
      debugPrint('🤚 ==========================================');

      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('🤚 ❌ Error sending poke: $e');
      debugPrint('🤚 Error type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('🤚 Response: ${e.response?.data}');
        debugPrint('🤚 Status code: ${e.response?.statusCode}');
      }
      debugPrint('🤚 ==========================================');
      rethrow;
    }
  }

  /// Get all pokes for the current user
  /// [page] - Page number for pagination
  /// [limit] - Number of pokes per page
  /// [unseenOnly] - If true, only fetch unseen pokes
  Future<Map<String, dynamic>> getPokes({
    int page = 1,
    int limit = 20,
    bool unseenOnly = false,
  }) async {
    try {
      debugPrint('📥 ==========================================');
      debugPrint(
        '📥 Fetching pokes (page: $page, limit: $limit, unseenOnly: $unseenOnly)',
      );
      debugPrint('📥 URL: ${HttpService.baseUrl}/pokes');

      final response = await _httpService.get(
        '/pokes',
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          'unseenOnly': unseenOnly.toString(),
        },
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response data: ${response.data}');

      final data = response.data as Map<String, dynamic>;
      final pokesData = data['data'];
      if (pokesData != null && pokesData is Map<String, dynamic>) {
        final pokes = pokesData['pokes'];
        debugPrint(
          '📥 ✅ Pokes retrieved: ${pokes is List ? pokes.length : 'unknown'}',
        );
      }
      debugPrint('📥 ==========================================');
      return data;
    } catch (e, stackTrace) {
      debugPrint('📥 ==========================================');
      debugPrint('📥 ❌ Error getting pokes: $e');
      debugPrint('📥 Error type: ${e.runtimeType}');
      if (e is DioException) {
        debugPrint('📥 DioException type: ${e.type}');
        debugPrint('📥 Response: ${e.response?.data}');
        debugPrint('📥 Status code: ${e.response?.statusCode}');
        debugPrint('📥 Message: ${e.message}');
      }
      debugPrint('📥 Stack trace: $stackTrace');
      debugPrint('📥 ==========================================');
      rethrow;
    }
  }

  /// Get count of unseen pokes
  Future<int> getUnseenCount() async {
    try {
      final response = await _httpService.get('/pokes/unseen-count');
      final data = response.data as Map<String, dynamic>;
      return data['data']['unseenCount'] as int;
    } catch (e) {
      debugPrint('❌ Error getting unseen pokes count: $e');
      rethrow;
    }
  }

  /// Mark a poke as seen
  /// [pokeId] - The ID of the poke to mark as seen
  Future<void> markPokeAsSeen(String pokeId) async {
    try {
      debugPrint('👀 Marking poke $pokeId as seen');

      await _httpService.put('/pokes/$pokeId/seen', data: {});

      debugPrint('✅ Poke marked as seen');
    } catch (e) {
      debugPrint('❌ Error marking poke as seen: $e');
      rethrow;
    }
  }

  /// Respond to a poke (poke back)
  /// [pokeId] - The ID of the original poke to respond to
  /// [pokeType] - Type of response poke: 'slap', 'kiss', 'hug', 'wave'
  Future<Map<String, dynamic>> respondToPoke(
    String pokeId,
    String pokeType,
  ) async {
    try {
      debugPrint('🤚 Responding to poke $pokeId with $pokeType');

      final response = await _httpService.post(
        '/pokes/$pokeId/respond',
        data: {'pokeType': pokeType},
      );

      debugPrint('✅ Poke response sent successfully');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error responding to poke: $e');
      rethrow;
    }
  }

  /// Delete a poke
  /// [pokeId] - The ID of the poke to delete
  Future<void> deletePoke(String pokeId) async {
    try {
      debugPrint('🗑️ Deleting poke $pokeId');

      await _httpService.delete('/pokes/$pokeId');

      debugPrint('✅ Poke deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting poke: $e');
      rethrow;
    }
  }
}
