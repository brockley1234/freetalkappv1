import 'dart:async';
import 'socket_service.dart';
import '../utils/app_logger.dart';

/// Service for handling realtime updates for posts, comments, and reactions
/// This service should be used by pages to listen for realtime changes
class RealtimeUpdateService {
  static final RealtimeUpdateService _instance =
      RealtimeUpdateService._internal();
  factory RealtimeUpdateService() => _instance;
  RealtimeUpdateService._internal();

  final _logger = AppLogger();
  final _socketService = SocketService();

  // Stream controllers for different types of updates
  final StreamController<Map<String, dynamic>> _postUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _postDeletedController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _postReactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _commentAddedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Story events
  final StreamController<Map<String, dynamic>> _storyCreatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _storyReactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _storyViewedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _storyDeletedController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _storyNewReplyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _storyReplyReactionController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _storyReplyDeletedController =
      StreamController<String>.broadcast();

  // Video events
  final StreamController<Map<String, dynamic>> _videoLikedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _videoCommentedController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Streams to listen to
  Stream<Map<String, dynamic>> get postUpdated => _postUpdatedController.stream;
  Stream<String> get postDeleted => _postDeletedController.stream;
  Stream<Map<String, dynamic>> get postReaction =>
      _postReactionController.stream;
  Stream<Map<String, dynamic>> get commentAdded =>
      _commentAddedController.stream;
  Stream<Map<String, dynamic>> get userStatusChanged =>
      _userStatusController.stream;

  // Story streams
  Stream<Map<String, dynamic>> get storyCreated =>
      _storyCreatedController.stream;
  Stream<Map<String, dynamic>> get storyReaction =>
      _storyReactionController.stream;
  Stream<Map<String, dynamic>> get storyViewed => _storyViewedController.stream;
  Stream<String> get storyDeleted => _storyDeletedController.stream;
  Stream<Map<String, dynamic>> get storyNewReply =>
      _storyNewReplyController.stream;
  Stream<Map<String, dynamic>> get storyReplyReaction =>
      _storyReplyReactionController.stream;
  Stream<String> get storyReplyDeleted =>
      _storyReplyDeletedController.stream;

  // Video streams
  Stream<Map<String, dynamic>> get videoLiked => _videoLikedController.stream;
  Stream<Map<String, dynamic>> get videoCommented =>
      _videoCommentedController.stream;

  bool _isInitialized = false;

  // Listener references for cleanup
  Function(dynamic)? _postUpdatedListener;
  Function(dynamic)? _postDeletedListener;
  Function(dynamic)? _postReactionListener;
  Function(dynamic)? _commentAddedListener;
  Function(dynamic)? _userStatusListener;
  Function(dynamic)? _storyCreatedListener;
  Function(dynamic)? _storyReactionListener;
  Function(dynamic)? _storyViewedListener;
  Function(dynamic)? _storyDeletedListener;
  Function(dynamic)? _storyNewReplyListener;
  Function(dynamic)? _storyReplyReactionListener;
  Function(dynamic)? _storyReplyDeletedListener;
  Function(dynamic)? _videoLikedListener;
  Function(dynamic)? _videoCommentedListener;

  void initialize() {
    if (_isInitialized) {
      _logger.debug('RealtimeUpdateService already initialized');
      return;
    }

    _logger.info('🔄 Initializing RealtimeUpdateService...');

    // Listen for post updates
    _postUpdatedListener = (data) {
      _logger.info('📡 post:updated event received');
      if (data != null && !_postUpdatedController.isClosed) {
        _postUpdatedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('post:updated', _postUpdatedListener!);

    // Listen for post deletions
    _postDeletedListener = (data) {
      _logger.info('📡 post:deleted event received');
      if (data != null && data['postId'] != null) {
        if (!_postDeletedController.isClosed) {
          _postDeletedController.add(data['postId'] as String);
        }
      }
    };
    _socketService.on('post:deleted', _postDeletedListener!);

    // Listen for post reactions
    _postReactionListener = (data) {
      _logger.info('📡 post:reaction event received');
      if (data != null && !_postReactionController.isClosed) {
        _postReactionController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('post:reaction', _postReactionListener!);

    // Listen for new comments
    _commentAddedListener = (data) {
      _logger.info('📡 comment:added event received');
      if (data != null && !_commentAddedController.isClosed) {
        _commentAddedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('comment:added', _commentAddedListener!);

    // Listen for user status changes
    _userStatusListener = (data) {
      _logger.debug('📡 user:status-changed event received');
      if (data != null && !_userStatusController.isClosed) {
        _userStatusController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('user:status-changed', _userStatusListener!);

    // Listen for story events
    _storyCreatedListener = (data) {
      _logger.info('📡 story:created event received');
      if (data != null && !_storyCreatedController.isClosed) {
        _storyCreatedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('story:created', _storyCreatedListener!);

    _storyReactionListener = (data) {
      _logger.info('📡 story:reaction event received');
      if (data != null && !_storyReactionController.isClosed) {
        _storyReactionController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('story:reaction', _storyReactionListener!);

    _storyViewedListener = (data) {
      _logger.info('📡 story:viewed event received');
      if (data != null && !_storyViewedController.isClosed) {
        _storyViewedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('story:viewed', _storyViewedListener!);

    _storyDeletedListener = (data) {
      _logger.info('📡 story:deleted event received');
      if (data != null && data['storyId'] != null) {
        if (!_storyDeletedController.isClosed) {
          _storyDeletedController.add(data['storyId'] as String);
        }
      }
    };
    _socketService.on('story:deleted', _storyDeletedListener!);

    // Listen for new story replies
    _storyNewReplyListener = (data) {
      _logger.info('📡 story:new_reply event received');
      if (data != null && !_storyNewReplyController.isClosed) {
        _storyNewReplyController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('story:new_reply', _storyNewReplyListener!);

    // Listen for story reply reactions
    _storyReplyReactionListener = (data) {
      _logger.info('📡 story:reply_reaction event received');
      if (data != null && !_storyReplyReactionController.isClosed) {
        _storyReplyReactionController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('story:reply_reaction', _storyReplyReactionListener!);

    // Listen for story reply deletions
    _storyReplyDeletedListener = (data) {
      _logger.info('📡 story:reply_deleted event received');
      if (data != null && data['replyId'] != null) {
        if (!_storyReplyDeletedController.isClosed) {
          _storyReplyDeletedController.add(data['replyId'] as String);
        }
      }
    };
    _socketService.on('story:reply_deleted', _storyReplyDeletedListener!);

    // Listen for video events
    _videoLikedListener = (data) {
      _logger.info('📡 video:liked event received');
      if (data != null && !_videoLikedController.isClosed) {
        _videoLikedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('video:liked', _videoLikedListener!);

    _videoCommentedListener = (data) {
      _logger.info('📡 video:commented event received');
      if (data != null && !_videoCommentedController.isClosed) {
        _videoCommentedController.add(data as Map<String, dynamic>);
      }
    };
    _socketService.on('video:commented', _videoCommentedListener!);

    _isInitialized = true;
    _logger
        .info('✅ RealtimeUpdateService initialized with all event listeners');
  }

  void dispose() {
    _logger.info('🔄 Disposing RealtimeUpdateService...');

    // Remove socket listeners
    if (_postUpdatedListener != null) {
      _socketService.off('post:updated', _postUpdatedListener);
      _postUpdatedListener = null;
    }

    if (_postDeletedListener != null) {
      _socketService.off('post:deleted', _postDeletedListener);
      _postDeletedListener = null;
    }

    if (_postReactionListener != null) {
      _socketService.off('post:reaction', _postReactionListener);
      _postReactionListener = null;
    }

    if (_commentAddedListener != null) {
      _socketService.off('comment:added', _commentAddedListener);
      _commentAddedListener = null;
    }

    if (_userStatusListener != null) {
      _socketService.off('user:status-changed', _userStatusListener);
      _userStatusListener = null;
    }

    if (_storyCreatedListener != null) {
      _socketService.off('story:created', _storyCreatedListener);
      _storyCreatedListener = null;
    }

    if (_storyReactionListener != null) {
      _socketService.off('story:reaction', _storyReactionListener);
      _storyReactionListener = null;
    }

    if (_storyViewedListener != null) {
      _socketService.off('story:viewed', _storyViewedListener);
      _storyViewedListener = null;
    }

    if (_storyDeletedListener != null) {
      _socketService.off('story:deleted', _storyDeletedListener);
      _storyDeletedListener = null;
    }

    if (_storyNewReplyListener != null) {
      _socketService.off('story:new_reply', _storyNewReplyListener);
      _storyNewReplyListener = null;
    }

    if (_storyReplyReactionListener != null) {
      _socketService.off('story:reply_reaction', _storyReplyReactionListener);
      _storyReplyReactionListener = null;
    }

    if (_storyReplyDeletedListener != null) {
      _socketService.off('story:reply_deleted', _storyReplyDeletedListener);
      _storyReplyDeletedListener = null;
    }

    if (_videoLikedListener != null) {
      _socketService.off('video:liked', _videoLikedListener);
      _videoLikedListener = null;
    }

    if (_videoCommentedListener != null) {
      _socketService.off('video:commented', _videoCommentedListener);
      _videoCommentedListener = null;
    }

    // Close stream controllers
    _postUpdatedController.close();
    _postDeletedController.close();
    _postReactionController.close();
    _commentAddedController.close();
    _userStatusController.close();
    _storyCreatedController.close();
    _storyReactionController.close();
    _storyViewedController.close();
    _storyDeletedController.close();
    _storyNewReplyController.close();
    _storyReplyReactionController.close();
    _storyReplyDeletedController.close();
    _videoLikedController.close();
    _videoCommentedController.close();

    _isInitialized = false;
  }
}
