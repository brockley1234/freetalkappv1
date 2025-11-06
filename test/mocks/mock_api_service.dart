/// Mock implementation of ApiService for testing
/// Note: Since ApiService uses static methods, we provide helper methods
/// to simulate API responses without implementing as interface
class MockApiService {
  // Helper methods for testing - these simulate API responses
  Future<Map<String, dynamic>> mockGet(String endpoint, {Map<String, dynamic>? headers, bool? useAuth}) async {
    return {
      'success': true,
      'data': {
        'id': 'mock_id',
        'name': 'Mock User',
        'email': 'test@example.com',
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> mockPost(String endpoint, {required Map<String, dynamic> body, Map<String, dynamic>? headers}) async {
    return {
      'success': true,
      'data': {'id': 'mock_id', ...body},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> mockPut(String endpoint, {required Map<String, dynamic> body, Map<String, dynamic>? headers}) async {
    return {
      'success': true,
      'data': {'id': 'mock_id', ...body},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> mockDelete(String endpoint) async {
    return {
      'success': true,
      'data': {},
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<bool> mockCheckIsAdmin() async => false;

  Future<Map<String, dynamic>> mockGetUserProfile(String userId) async {
    return {
      'success': true,
      'data': {
        'id': userId,
        'name': 'Test User',
        'email': 'test@example.com',
        'profilePicture': null,
        'bio': 'Test bio',
        'followers': [],
        'following': [],
        'posts': [],
        'badges': [],
        'achievements': [],
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> mockGetUserPosts(String userId, {int? page}) async {
    return [];
  }

  Future<Map<String, dynamic>> mockCreatePost({required Map<String, dynamic> body}) async {
    return {
      'success': true,
      'data': {
        'id': 'post_123',
        'userId': 'user_123',
        'content': body['content'],
        'createdAt': DateTime.now().toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> mockGetConversations() async {
    return {
      'success': true,
      'data': [],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> mockGetMessages(String conversationId) async {
    return [];
  }

  Future<Map<String, dynamic>> mockSendMessage({required String conversationId, required String message}) async {
    return {
      'success': true,
      'data': {
        'id': 'msg_123',
        'conversationId': conversationId,
        'message': message,
        'createdAt': DateTime.now().toIso8601String(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> mockLikePost(String postId) async {
    return {'success': true, 'data': {}, 'timestamp': DateTime.now().toIso8601String()};
  }

  Future<Map<String, dynamic>> mockUnlikePost(String postId) async {
    return {'success': true, 'data': {}, 'timestamp': DateTime.now().toIso8601String()};
  }

  Future<Map<String, dynamic>> mockFollowUser(String userId) async {
    return {'success': true, 'data': {}, 'timestamp': DateTime.now().toIso8601String()};
  }

  Future<Map<String, dynamic>> mockUnfollowUser(String userId) async {
    return {'success': true, 'data': {}, 'timestamp': DateTime.now().toIso8601String()};
  }

  void mockSetBaseUrl(String url) {}

  void mockSetToken(String token) {}

  void mockClearToken() {}
}
