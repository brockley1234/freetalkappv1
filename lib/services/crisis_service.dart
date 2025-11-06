import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'socket_service.dart';
import '../config/app_config.dart';
import 'secure_storage_service.dart';

class CrisisService extends ChangeNotifier {
  static final CrisisService _instance = CrisisService._internal();
  factory CrisisService() => _instance;
  CrisisService._internal();

  String get _baseUrl => AppConfig.baseUrl;

  List<CrisisResponse> _activeCrises = [];
  List<CrisisResponse> _userCrisisHistory = [];
  final Map<String, List<Function(Map<String, dynamic>)>> _crisisListeners = {};

  List<CrisisResponse> get activeCrises => _activeCrises;
  List<CrisisResponse> get userCrisisHistory => _userCrisisHistory;

  // Get token dynamically for each request
  Future<String?> _getToken() async {
    return await SecureStorageService().getAccessToken();
  }

  Future<void> init() async {
    // Set up socket listeners for crisis events
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socketService = SocketService();

    // New crisis alert
    socketService.on('new_crisis_alert', (data) {
      debugPrint('📢 New crisis alert received: $data');
      fetchActiveCrisis();
      notifyListeners();
    });

    // Crisis help offered
    socketService.on('crisis_help_offered', (data) {
      debugPrint('🤝 Crisis help offered: $data');
      _updateCrisisInList(data['crisisId'], data);
      notifyListeners();
    });

    // Crisis safety check
    socketService.on('crisis_safety_check', (data) {
      debugPrint('✅ Crisis safety check: $data');
      _updateCrisisInList(data['crisisId'], data);
      notifyListeners();
    });

    // Crisis update
    socketService.on('crisis_update', (data) {
      debugPrint('📝 Crisis update: $data');
      _notifyCrisisListeners(data['crisisId'], data);
      notifyListeners();
    });

    // Crisis resolved
    socketService.on('crisis_resolved', (data) {
      debugPrint('🎉 Crisis resolved: $data');
      _updateCrisisInList(data['crisisId'], data);
      fetchActiveCrisis();
      notifyListeners();
    });

    // Emergency broadcast
    socketService.on('crisis:emergency', (data) {
      debugPrint('🚨 EMERGENCY CRISIS ALERT: $data');
      // This should trigger a high-priority notification
      fetchActiveCrisis();
      notifyListeners();
    });

    // New crisis update in real-time
    socketService.on('crisis:new-update', (data) {
      debugPrint('📨 Crisis new update: $data');
      _notifyCrisisListeners(data['crisisId'], data);
    });

    // Crisis resource added
    socketService.on('crisis_resource_added', (data) {
      debugPrint('📚 Crisis resource added: $data');
      _notifyCrisisListeners(data['crisisId'], data);
    });
  }

  void _updateCrisisInList(String crisisId, Map<String, dynamic> data) {
    final index = _activeCrises.indexWhere((c) => c.id == crisisId);
    if (index != -1) {
      // Refresh this specific crisis
      fetchCrisisById(crisisId);
    }
  }

  void _notifyCrisisListeners(String crisisId, Map<String, dynamic> data) {
    if (_crisisListeners.containsKey(crisisId)) {
      for (var listener in _crisisListeners[crisisId]!) {
        listener(data);
      }
    }
  }

  void addCrisisListener(
      String crisisId, Function(Map<String, dynamic>) listener) {
    if (!_crisisListeners.containsKey(crisisId)) {
      _crisisListeners[crisisId] = [];
    }
    _crisisListeners[crisisId]!.add(listener);

    // Join the crisis room for real-time updates
    SocketService().emit('crisis:join', {'crisisId': crisisId});
  }

  void removeCrisisListener(
      String crisisId, Function(Map<String, dynamic>) listener) {
    if (_crisisListeners.containsKey(crisisId)) {
      _crisisListeners[crisisId]!.remove(listener);
      if (_crisisListeners[crisisId]!.isEmpty) {
        _crisisListeners.remove(crisisId);
        // Leave the crisis room
        SocketService().emit('crisis:leave', {'crisisId': crisisId});
      }
    }
  }

  // Create a new crisis response request
  Future<CrisisResponse?> createCrisis({
    required String crisisType,
    required String severity,
    required String description,
    Map<String, dynamic>? location,
    String? contactPhone,
    bool isAnonymous = false,
    String visibility = 'friends',
    List<String>? emergencyContactIds,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'crisisType': crisisType,
          'severity': severity,
          'description': description,
          'location': location,
          'contactPhone': contactPhone,
          'isAnonymous': isAnonymous,
          'visibility': visibility,
          'emergencyContactIds': emergencyContactIds,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final crisis = CrisisResponse.fromJson(data['crisisResponse']);
        await fetchActiveCrisis();
        notifyListeners();
        return crisis;
      } else {
        debugPrint('Failed to create crisis: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating crisis: $e');
      return null;
    }
  }

  // Fetch active crisis alerts
  Future<void> fetchActiveCrisis({String? severity, String? crisisType}) async {
    try {
      final token = await _getToken();
      var url = '$_baseUrl/crisis/active?limit=50';
      if (severity != null) url += '&severity=$severity';
      if (crisisType != null) url += '&crisisType=$crisisType';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _activeCrises = (data['crisisAlerts'] as List)
            .map((json) => CrisisResponse.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching active crisis: $e');
    }
  }

  // Fetch a specific crisis by ID
  Future<CrisisResponse?> fetchCrisisById(String crisisId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/crisis/$crisisId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CrisisResponse.fromJson(data['crisisResponse']);
      }
    } catch (e) {
      debugPrint('Error fetching crisis: $e');
    }
    return null;
  }

  // Offer help for a crisis
  Future<bool> offerHelp(String crisisId, {String? message}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis/$crisisId/offer-help'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message ?? 'I am here to help',
        }),
      );

      if (response.statusCode == 200) {
        await fetchActiveCrisis();
        return true;
      }
    } catch (e) {
      debugPrint('Error offering help: $e');
    }
    return false;
  }

  // Perform a safety check
  Future<bool> performSafetyCheck(String crisisId, String status,
      {String? message}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis/$crisisId/safety-check'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': status,
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error performing safety check: $e');
      return false;
    }
  }

  // Add an update to a crisis
  Future<bool> addUpdate(String crisisId, String message) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis/$crisisId/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding update: $e');
      return false;
    }
  }

  // Send update via socket (real-time)
  void sendUpdateRealtime(String crisisId, String message) {
    SocketService().emit('crisis:send-update', {
      'crisisId': crisisId,
      'message': message,
    });
  }

  // Resolve a crisis
  Future<bool> resolveCrisis(String crisisId, {String? message}) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis/$crisisId/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'message': message ?? 'Crisis resolved',
        }),
      );

      if (response.statusCode == 200) {
        await fetchActiveCrisis();
        return true;
      }
    } catch (e) {
      debugPrint('Error resolving crisis: $e');
    }
    return false;
  }

  // Add a resource to a crisis
  Future<bool> addResource(
    String crisisId, {
    required String type,
    required String name,
    required String contact,
    String? description,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$_baseUrl/crisis/$crisisId/resource'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'type': type,
          'name': name,
          'contact': contact,
          'description': description,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding resource: $e');
      return false;
    }
  }

  // Fetch user's crisis history
  Future<void> fetchUserCrisisHistory({String? status}) async {
    try {
      final token = await _getToken();
      var url = '$_baseUrl/crisis/user/history?limit=50';
      if (status != null) url += '&status=$status';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _userCrisisHistory = (data['crisisHistory'] as List)
            .map((json) => CrisisResponse.fromJson(json))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching crisis history: $e');
    }
  }

  // Get emergency resources
  Future<Map<String, dynamic>?> getEmergencyResources(String crisisType) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/crisis/resources/$crisisType'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching emergency resources: $e');
    }
    return null;
  }

  // Send emergency broadcast
  void sendEmergencyBroadcast(String crisisId, {String? message}) {
    SocketService().emit('crisis:emergency-broadcast', {
      'crisisId': crisisId,
      'message': message,
    });
  }

  // Notify that user is viewing a crisis
  void notifyViewing(String crisisId) {
    SocketService().emit('crisis:viewing', {
      'crisisId': crisisId,
    });
  }
}

// Crisis Response Model
class CrisisResponse {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String crisisType;
  final String severity;
  final String description;
  final Map<String, dynamic>? location;
  final String? contactPhone;
  final String status;
  final bool isAnonymous;
  final String visibility;
  final List<Helper> helpers;
  final List<SafetyCheck> safetyChecks;
  final List<Update> updates;
  final List<Resource> resources;
  final DateTime createdAt;
  final DateTime updatedAt;

  CrisisResponse({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.crisisType,
    required this.severity,
    required this.description,
    this.location,
    this.contactPhone,
    required this.status,
    required this.isAnonymous,
    required this.visibility,
    required this.helpers,
    required this.safetyChecks,
    required this.updates,
    required this.resources,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CrisisResponse.fromJson(Map<String, dynamic> json) {
    // Handle user field - can be either a String (ID) or an Object
    final user = json['user'];
    final String userId;
    final String userName;
    final String? userProfilePicture;

    if (user is String) {
      // User is just an ID string
      userId = user;
      userName = 'Anonymous';
      userProfilePicture = null;
    } else if (user is Map<String, dynamic>) {
      // User is a full object
      userId = user['_id'] ?? '';
      userName = user['name'] ?? 'Anonymous';
      userProfilePicture = user['profilePicture'];
    } else {
      // Fallback
      userId = '';
      userName = 'Anonymous';
      userProfilePicture = null;
    }

    return CrisisResponse(
      id: json['_id'],
      userId: userId,
      userName: userName,
      userProfilePicture: userProfilePicture,
      crisisType: json['crisisType'],
      severity: json['severity'],
      description: json['description'],
      location: json['location'],
      contactPhone: json['contactPhone'],
      status: json['status'],
      isAnonymous: json['isAnonymous'] ?? false,
      visibility: json['visibility'],
      helpers:
          (json['helpers'] as List?)?.map((h) => Helper.fromJson(h)).toList() ??
              [],
      safetyChecks: (json['safetyChecks'] as List?)
              ?.map((s) => SafetyCheck.fromJson(s))
              .toList() ??
          [],
      updates:
          (json['updates'] as List?)?.map((u) => Update.fromJson(u)).toList() ??
              [],
      resources: (json['resourcesProvided'] as List?)
              ?.map((r) => Resource.fromJson(r))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class Helper {
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String status;
  final String message;
  final DateTime respondedAt;

  Helper({
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.status,
    required this.message,
    required this.respondedAt,
  });

  factory Helper.fromJson(Map<String, dynamic> json) {
    // Handle user field - can be either a String (ID) or an Object
    final user = json['user'];
    final String userId;
    final String userName;
    final String? userProfilePicture;

    if (user is String) {
      userId = user;
      userName = 'Anonymous';
      userProfilePicture = null;
    } else if (user is Map<String, dynamic>) {
      userId = user['_id'] ?? '';
      userName = user['name'] ?? 'Anonymous';
      userProfilePicture = user['profilePicture'];
    } else {
      userId = '';
      userName = 'Anonymous';
      userProfilePicture = null;
    }

    return Helper(
      userId: userId,
      userName: userName,
      userProfilePicture: userProfilePicture,
      status: json['status'],
      message: json['message'] ?? '',
      respondedAt: DateTime.parse(json['respondedAt']),
    );
  }
}

class SafetyCheck {
  final String checkedById;
  final String checkedByName;
  final String? checkedByProfilePicture;
  final String status;
  final String message;
  final DateTime checkedAt;

  SafetyCheck({
    required this.checkedById,
    required this.checkedByName,
    this.checkedByProfilePicture,
    required this.status,
    required this.message,
    required this.checkedAt,
  });

  factory SafetyCheck.fromJson(Map<String, dynamic> json) {
    // Handle checkedBy field - can be either a String (ID) or an Object
    final checkedBy = json['checkedBy'];
    final String checkedById;
    final String checkedByName;
    final String? checkedByProfilePicture;

    if (checkedBy is String) {
      checkedById = checkedBy;
      checkedByName = 'Anonymous';
      checkedByProfilePicture = null;
    } else if (checkedBy is Map<String, dynamic>) {
      checkedById = checkedBy['_id'] ?? '';
      checkedByName = checkedBy['name'] ?? 'Anonymous';
      checkedByProfilePicture = checkedBy['profilePicture'];
    } else {
      checkedById = '';
      checkedByName = 'Anonymous';
      checkedByProfilePicture = null;
    }

    return SafetyCheck(
      checkedById: checkedById,
      checkedByName: checkedByName,
      checkedByProfilePicture: checkedByProfilePicture,
      status: json['status'],
      message: json['message'] ?? '',
      checkedAt: DateTime.parse(json['checkedAt']),
    );
  }
}

class Update {
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String message;
  final DateTime timestamp;

  Update({
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.message,
    required this.timestamp,
  });

  factory Update.fromJson(Map<String, dynamic> json) {
    // Handle user field - can be either a String (ID) or an Object
    final user = json['user'];
    final String userId;
    final String userName;
    final String? userProfilePicture;

    if (user is String) {
      userId = user;
      userName = 'Anonymous';
      userProfilePicture = null;
    } else if (user is Map<String, dynamic>) {
      userId = user['_id'] ?? '';
      userName = user['name'] ?? 'Anonymous';
      userProfilePicture = user['profilePicture'];
    } else {
      userId = '';
      userName = 'Anonymous';
      userProfilePicture = null;
    }

    return Update(
      userId: userId,
      userName: userName,
      userProfilePicture: userProfilePicture,
      message: json['message'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class Resource {
  final String type;
  final String name;
  final String contact;
  final String? description;
  final String providedById;
  final String providedByName;
  final DateTime providedAt;

  Resource({
    required this.type,
    required this.name,
    required this.contact,
    this.description,
    required this.providedById,
    required this.providedByName,
    required this.providedAt,
  });

  factory Resource.fromJson(Map<String, dynamic> json) {
    // Handle providedBy field - can be either a String (ID) or an Object
    final providedBy = json['providedBy'];
    final String providedById;
    final String providedByName;

    if (providedBy is String) {
      providedById = providedBy;
      providedByName = 'Anonymous';
    } else if (providedBy is Map<String, dynamic>) {
      providedById = providedBy['_id'] ?? '';
      providedByName = providedBy['name'] ?? 'Anonymous';
    } else {
      providedById = '';
      providedByName = 'Anonymous';
    }

    return Resource(
      type: json['type'],
      name: json['name'],
      contact: json['contact'],
      description: json['description'],
      providedById: providedById,
      providedByName: providedByName,
      providedAt: DateTime.parse(json['providedAt']),
    );
  }
}
