import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class GroupService {
  static String get _base => ApiService.baseUrl;

  static Future<Map<String, dynamic>> listGroups({String q = '', int page = 1, int limit = 20}) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final uri = Uri.parse('$_base/groups').replace(queryParameters: {
        if (q.isNotEmpty) 'q': q,
        'page': page.toString(),
        'limit': limit.toString(),
      });
      final res = await http.get(uri, headers: headers);
      return res;
    });
  }

  static Future<Map<String, dynamic>> myGroups() async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final res = await http.get(Uri.parse('$_base/groups/mine'), headers: headers);
      return res;
    });
  }

  static Future<Map<String, dynamic>> getGroup(String groupId) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final res = await http.get(Uri.parse('$_base/groups/$groupId'), headers: headers);
      return res;
    });
  }

  static Future<Map<String, dynamic>> createGroup({required String name, String? description, String privacy = 'public'}) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final body = jsonEncode({
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        'privacy': privacy,
      });
      final res = await http.post(Uri.parse('$_base/groups'), headers: headers, body: body);
      return res;
    });
  }

  static Future<Map<String, dynamic>> joinGroup(String groupId) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final res = await http.post(Uri.parse('$_base/groups/$groupId/join'), headers: headers);
      return res;
    });
  }

  static Future<Map<String, dynamic>> leaveGroup(String groupId) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final res = await http.post(Uri.parse('$_base/groups/$groupId/leave'), headers: headers);
      return res;
    });
  }

  static Future<Map<String, dynamic>> listMembers(String groupId) async {
    return await ApiService.makeAuthenticated(() async {
      final headers = await ApiService.getAuthHeaders();
      final res = await http.get(Uri.parse('$_base/groups/$groupId/members'), headers: headers);
      return res;
    });
  }
}


