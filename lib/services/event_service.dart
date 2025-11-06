import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/event_model.dart';
import 'api_service.dart';

class EventService {
  final String baseUrl = ApiConfig.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await ApiService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Create event
  Future<Event> createEvent(Map<String, dynamic> eventData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: headers,
        body: jsonEncode(eventData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Event.fromJson(data['data']);
      } else {
        // Throw structured ApiException so UI can show user-friendly validation details
        Map<String, dynamic>? data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {}

        final message = data != null && data['message'] is String ? data['message'] as String : 'An error occurred';
        final errors = data != null && data['errors'] is List ? List<dynamic>.from(data['errors']) : null;

        throw ApiException(
          statusCode: response.statusCode,
          message: message,
          errors: errors,
        );
      }
    } catch (e) {
      // Preserve ApiException to the UI for better messaging
      if (e is ApiException) rethrow;
      throw Exception('Error creating event: $e');
    }
  }

  // Get my events
  Future<List<Event>> getMyEvents({int page = 1, int limit = 20}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/events/mine?page=$page&limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List eventsJson = data['data']['events'];
        return eventsJson.map((e) => Event.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch events');
      }
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

  // Get event by ID
  Future<Event> getEvent(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Event.fromJson(data['data']);
      } else {
        throw Exception('Failed to fetch event');
      }
    } catch (e) {
      throw Exception('Error fetching event: $e');
    }
  }

  // Update event
  Future<Event> updateEvent(
      String eventId, Map<String, dynamic> eventData) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: headers,
        body: jsonEncode(eventData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Event.fromJson(data['data']);
      } else {
        throw Exception('Failed to update event');
      }
    } catch (e) {
      throw Exception('Error updating event: $e');
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete event');
      }
    } catch (e) {
      throw Exception('Error deleting event: $e');
    }
  }

  // RSVP to event
  Future<Map<String, dynamic>> rsvpEvent(String eventId, String status,
      {bool joinWaitlist = false}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/rsvp'),
        headers: headers,
        body: jsonEncode({'status': status, 'joinWaitlist': joinWaitlist}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'Failed to RSVP');
      }
    } catch (e) {
      throw Exception('Error RSVPing: $e');
    }
  }

  // Accept invitation
  Future<void> acceptInvitation(String eventId,
      {String autoRSVP = 'interested', bool joinWaitlist = false}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/invite/accept'),
        headers: headers,
        body: jsonEncode({'autoRSVP': autoRSVP, 'joinWaitlist': joinWaitlist}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to accept invitation');
      }
    } catch (e) {
      throw Exception('Error accepting invitation: $e');
    }
  }

  // Decline invitation
  Future<void> declineInvitation(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/invite/decline'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to decline invitation');
      }
    } catch (e) {
      throw Exception('Error declining invitation: $e');
    }
  }

  // Invite users
  Future<void> inviteUsers(String eventId, List<String> userIds) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/invite'),
        headers: headers,
        body: jsonEncode({'userIds': userIds}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to invite users');
      }
    } catch (e) {
      throw Exception('Error inviting users: $e');
    }
  }

  // Get attendees
  Future<List<Map<String, dynamic>>> getAttendees(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/events/$eventId/attendees'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to fetch attendees');
      }
    } catch (e) {
      throw Exception('Error fetching attendees: $e');
    }
  }

  // Check in
  Future<void> checkIn(String eventId,
      {String method = 'code', String? locationName}) async {
    try {
      final headers = await _getHeaders();
      final body = {'method': method};
      if (locationName != null) body['locationName'] = locationName;

      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/checkin'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to check in');
      }
    } catch (e) {
      throw Exception('Error checking in: $e');
    }
  }

  // Discover events
  Future<List<Event>> discoverEvents({
    String? query,
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? visibility,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (query != null && query.isNotEmpty) params['q'] = query;
      if (from != null) params['from'] = from.toIso8601String();
      if (to != null) params['to'] = to.toIso8601String();
      if (visibility != null) params['visibility'] = visibility;

      final uri = Uri.parse('$baseUrl/events/discover/list')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List eventsJson = data['data']['events'];
        return eventsJson.map((e) => Event.fromJson(e)).toList();
      } else {
        throw Exception('Failed to discover events');
      }
    } catch (e) {
      throw Exception('Error discovering events: $e');
    }
  }

  // Nearby events
  Future<List<Event>> getNearbyEvents({
    required double lat,
    required double lng,
    int maxDistance = 10000,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'maxDistance': maxDistance.toString(),
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final uri = Uri.parse('$baseUrl/events/discover/nearby')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List eventsJson = data['data']['events'];
        return eventsJson.map((e) => Event.fromJson(e)).toList();
      } else {
        throw Exception('Failed to fetch nearby events');
      }
    } catch (e) {
      throw Exception('Error fetching nearby events: $e');
    }
  }

  // Join waitlist
  Future<Map<String, dynamic>> joinWaitlist(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/waitlist/join'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['data'];
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Failed to join waitlist');
      }
    } catch (e) {
      throw Exception('Error joining waitlist: $e');
    }
  }

  // Leave waitlist
  Future<void> leaveWaitlist(String eventId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/events/$eventId/waitlist/leave'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to leave waitlist');
      }
    } catch (e) {
      throw Exception('Error leaving waitlist: $e');
    }
  }

  // Download iCal file
  String getICalUrl(String eventId) {
    return '$baseUrl/events/$eventId/ical';
  }
}
