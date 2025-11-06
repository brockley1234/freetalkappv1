import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../services/api_service.dart';
import '../../utils/auth_storage.dart';
import '../../utils/event_utils.dart';
import '../user_profile_page.dart';
import 'create_event_page.dart';
import 'manage_attendees_page.dart';

class EventDetailPage extends StatefulWidget {
  final String eventId;

  const EventDetailPage({super.key, required this.eventId});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  final EventService _eventService = EventService();
  Event? _event;
  bool _isLoading = true;
  String? _currentUserId;
  final Map<String, String> _userNames = {}; // Map user IDs to display names
  String? _organizerName;
  String? _organizerAvatar;

  @override
  void initState() {
    super.initState();
    _loadEvent();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    _currentUserId = await AuthStorage.getUserId();
    setState(() {});
  }

  Future<void> _loadEvent() async {
    setState(() => _isLoading = true);
    try {
      final event = await _eventService.getEvent(widget.eventId);
      
      // Debug: Log event data to see what we're working with
      if (kDebugMode) {
        print('DEBUG: Event Detail - Loaded event: ${event.title}');
        print('DEBUG: Event Detail - coverImage: ${event.coverImage}');
        print('DEBUG: Event Detail - has coverImage: ${event.coverImage != null && event.coverImage!.isNotEmpty}');
      }
      
      setState(() {
        _event = event;
      });

      // Load organizer info
      await _loadOrganizerInfo();

      // Load user names for all attendees
      await _loadUserNames();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  Future<void> _loadOrganizerInfo() async {
    if (_event == null) return;

    // Use populated organizer data if available
    if (_event!.organizerName != null && _event!.organizerName!.isNotEmpty) {
      setState(() {
        _organizerName = _event!.organizerName;
        _organizerAvatar = _event!.organizerAvatar;
      });
      return;
    }

    // Fallback to API call if organizer data not populated
    try {
      final response = await ApiService.getUserById(_event!.organizer);
      // The API returns {success: true, data: {user: {...}}}
      final userData = response['data']?['user'] ?? response;
      setState(() {
        _organizerName = userData['name'] ?? userData['username'] ?? 'Unknown';
        _organizerAvatar = userData['avatar'];
      });
    } catch (e) {
      setState(() {
        _organizerName = 'Unknown';
      });
    }
  }

  Future<void> _loadUserNames() async {
    if (_event == null) return;

    // Get unique user IDs from RSVPs
    final userIds = _event!.rsvps.map((r) => r.user).toSet();

    // Fetch user details for each user
    for (final userId in userIds) {
      try {
        final response = await ApiService.getUserById(userId);
        // The API returns {success: true, data: {user: {...}}}
        final userData = response['data']?['user'] ?? response;
        if (userData['name'] != null || userData['username'] != null) {
          _userNames[userId] = userData['name'] ?? userData['username'] ?? 'User';
        } else {
          _userNames[userId] = 'User';
        }
      } catch (e) {
        // If we can't fetch the user, use a fallback
        _userNames[userId] = 'User';
      }
    }
  }

  Future<void> _handleRSVP(String status) async {
    try {
      await _eventService.rsvpEvent(widget.eventId, status);
      _loadEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RSVP updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if event is full
        if (e.toString().contains('full') ||
            e.toString().contains('capacity')) {
          final result = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Event Full'),
              content: const Text(
                  'This event is at capacity. Would you like to join the waitlist?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Join Waitlist'),
                ),
              ],
            ),
          );
          if (result == true) {
            await _joinWaitlist();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _joinWaitlist() async {
    try {
      await _eventService.joinWaitlist(widget.eventId);
      _loadEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to waitlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining waitlist: $e')),
        );
      }
    }
  }

  Future<void> _leaveWaitlist() async {
    try {
      await _eventService.leaveWaitlist(widget.eventId);
      _loadEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from waitlist')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _checkIn() async {
    try {
      await _eventService.checkIn(widget.eventId, method: 'manual');
      _loadEvent();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e')),
        );
      }
    }
  }

  Future<void> _downloadICalendar() async {
    try {
      final url = _eventService.getICalUrl(widget.eventId);
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading calendar: $e')),
        );
      }
    }
  }

  String? _getUserRSVPStatus() {
    if (_event == null || _currentUserId == null) return null;
    try {
      final rsvp = _event!.rsvps.firstWhere(
        (r) => r.user == _currentUserId,
      );
      return rsvp.status;
    } catch (e) {
      return null;
    }
  }

  bool _isOnWaitlist() {
    if (_event == null || _currentUserId == null) return false;
    return _event!.waitlist.contains(_currentUserId);
  }

  bool _isOrganizer() {
    if (_event == null || _currentUserId == null) return false;
    return _event!.organizer == _currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Details')),
        body: const Center(child: Text('Event not found')),
      );
    }

    final userRSVP = _getUserRSVPStatus();
    final onWaitlist = _isOnWaitlist();
    final isOrganizer = _isOrganizer();
    final status = EventUtils.getEventStatus(_event!);
    final isAtCapacity = EventUtils.isAtCapacity(_event!);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadEvent,
        child: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  if (_event!.coverImage != null &&
                      _event!.coverImage!.isNotEmpty)
                    Builder(
                      builder: (context) {
                        // Decode URL-encoded characters in the image path
                        final decodedPath = Uri.decodeComponent(_event!.coverImage!);
                        
                        // Construct the proper image URL
                        String imageUrl;
                        if (decodedPath.startsWith('http')) {
                          imageUrl = decodedPath;
                        } else if (decodedPath.startsWith('/uploads/')) {
                          // Convert /uploads/ to /api/uploads/ for proper CORS headers
                          imageUrl = 'https://freetalk.site/api$decodedPath';
                        } else if (decodedPath.startsWith('/')) {
                          // If it starts with /, use the base URL
                          imageUrl = 'https://freetalk.site$decodedPath';
                        } else {
                          // If it doesn't start with /, add it
                          imageUrl = 'https://freetalk.site/$decodedPath';
                        }
                        
                        // Debug logging to see the actual URLs being constructed
                        if (kDebugMode) {
                          print('DEBUG: Event Detail - Original coverImage: ${_event!.coverImage}');
                          print('DEBUG: Event Detail - Decoded path: $decodedPath');
                          print('DEBUG: Event Detail - Final imageUrl: $imageUrl');
                        }
                        
                        return CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (context, url, error) {
                            if (kDebugMode) {
                              print('DEBUG: Event Detail - Image load error for URL: $url');
                              print('DEBUG: Event Detail - Error: $error');
                            }
                            return _buildPlaceholderCover();
                          },
                        );
                      },
                    )
                  else
                    _buildPlaceholderCover(),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),

                  // Status badge at top right
                  Positioned(
                    top: 100,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: EventUtils.getStatusColor(status),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        EventUtils.getStatusLabel(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _downloadICalendar,
                tooltip: 'Add to Calendar',
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareEvent,
                tooltip: 'Share',
              ),
              if (isOrganizer)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateEventPage(eventId: widget.eventId),
                      ),
                    );
                    // Reload event if it was edited
                    if (result == true) {
                      _loadEvent();
                    }
                  },
                  tooltip: 'Edit Event',
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        _event!.title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: EventUtils.getStatusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              EventUtils.getStatusLabel(status),
                              style: TextStyle(
                                color: EventUtils.getStatusColor(status),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (_event!.capacity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: (isAtCapacity ? Colors.red : Theme.of(context).primaryColor)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people,
                                    size: 14,
                                    color: isAtCapacity ? Colors.red : Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${_event!.rsvps.where((r) => r.status == 'going').length} / ${_event!.capacity}',
                                    style: TextStyle(
                                      color: isAtCapacity ? Colors.red : Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Organizer info
                      if (_organizerName != null) ...[
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfilePage(
                                  userId: _event!.organizer,
                                ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: _organizerAvatar != null
                                    ? CachedNetworkImageProvider(
                                        _organizerAvatar!)
                                    : null,
                                child: _organizerAvatar == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Organized by',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _organizerName!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                      ],

                      // Event details cards
                      _buildInfoCard(
                        icon: Icons.access_time,
                        title: 'Date & Time',
                        content: EventUtils.formatDateRange(
                            _event!.startTime, _event!.endTime),
                        subtitle: EventUtils.getRelativeTime(_event!.startTime),
                      ),
                      const SizedBox(height: 12),

                      if (_event!.locationName != null)
                        _buildInfoCard(
                          icon: Icons.location_on,
                          title: 'Location',
                          content: _event!.locationName!,
                          subtitle: _event!.locationAddress,
                          onTap: _event!.latitude != null &&
                                  _event!.longitude != null
                              ? () async {
                                  final url =
                                      'https://www.google.com/maps/search/?api=1&query=${_event!.latitude},${_event!.longitude}';
                                  if (await canLaunchUrl(Uri.parse(url))) {
                                    await launchUrl(Uri.parse(url));
                                  }
                                }
                              : null,
                        ),

                      if (_event!.capacity != null) ...[
                        const SizedBox(height: 12),
                        _buildCapacityCard(),
                      ],

                      const SizedBox(height: 24),

                      // About section
                      Text(
                        'About This Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _event!.description,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),

                      // Tags
                      if (_event!.tags.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Tags',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _event!.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    EventUtils.getTagIcon(tag),
                                    size: 16,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 24),

                      // Attendees section
                      _buildAttendeesSection(),

                      const SizedBox(height: 100), // Space for bottom buttons
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),

      // Bottom action buttons
      bottomNavigationBar:
          _buildBottomActions(userRSVP, onWaitlist, isOrganizer, isAtCapacity),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple[400]!,
            Colors.blue[400]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event, size: 100, color: Colors.white70),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapacityCard() {
    final goingCount = _event!.rsvps.where((r) => r.status == 'going').length;
    final percentage = EventUtils.getAttendancePercentage(_event!);
    final isAtCapacity = EventUtils.isAtCapacity(_event!);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAtCapacity ? Colors.red[300]! : Colors.grey[300]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAtCapacity
                        ? Colors.red[50]
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.people,
                    color: isAtCapacity
                        ? Colors.red[700]
                        : Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$goingCount / ${_event!.capacity}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAtCapacity)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'FULL',
                      style: TextStyle(
                        color: Colors.red[900],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isAtCapacity ? Colors.red : Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toStringAsFixed(0)}% full',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendeesSection() {
    final going = _event!.rsvps.where((r) => r.status == 'going').toList();
    final interested =
        _event!.rsvps.where((r) => r.status == 'interested').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attendees (${going.length + interested.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (going.isNotEmpty || interested.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageAttendeesPage(event: _event!),
                    ),
                  );
                },
                icon: const Icon(Icons.list, size: 20),
                label: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (going.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.check_circle, size: 20, color: Colors.green[600]),
              const SizedBox(width: 8),
              Text(
                'Going (${going.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: going.take(20).map((rsvp) {
              final userName = _userNames[rsvp.user] ?? 'Loading...';
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfilePage(userId: rsvp.user),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(40),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      child: Text(userName[0].toUpperCase()),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60,
                      child: Text(
                        userName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          if (going.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '+ ${going.length - 20} more',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
        if (interested.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.star, size: 20, color: Colors.orange[600]),
              const SizedBox(width: 8),
              Text(
                'Interested (${interested.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            interested
                .map((r) => _userNames[r.user] ?? 'Loading...')
                .take(10)
                .join(', '),
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          if (interested.length > 10)
            Text(
              ' and ${interested.length - 10} more',
              style: TextStyle(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
        ],
        if (going.isEmpty && interested.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No attendees yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to RSVP!',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget? _buildBottomActions(
      String? userRSVP, bool onWaitlist, bool isOrganizer, bool isAtCapacity) {
    if (isOrganizer) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userRSVP == 'going')
                ElevatedButton.icon(
                  onPressed: _checkIn,
                  icon: const Icon(Icons.check_box),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              if (userRSVP == 'going') const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageAttendeesPage(event: _event!),
                    ),
                  );
                },
                icon: const Icon(Icons.people),
                label: const Text('Manage Attendees'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (onWaitlist) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.hourglass_empty, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You\'re on the waitlist',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[900],
                          ),
                        ),
                        Text(
                          'We\'ll notify you if a spot opens up',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _leaveWaitlist,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.orange[700]!),
                ),
                child: Text(
                  'Leave Waitlist',
                  style: TextStyle(color: Colors.orange[900]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Regular user - show RSVP buttons
    final disableGoing = isAtCapacity && userRSVP != 'going';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: (userRSVP == 'going' || disableGoing)
                        ? null
                        : () => _handleRSVP('going'),
                    icon: Icon(userRSVP == 'going'
                        ? Icons.check_circle
                        : Icons.check_circle_outline),
                    label: const Text('Going'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: userRSVP == 'going'
                          ? Colors.green[600]
                          : (disableGoing ? Colors.grey[300] : null),
                      foregroundColor:
                          userRSVP == 'going' ? Colors.white : null,
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: userRSVP == 'interested'
                        ? null
                        : () => _handleRSVP('interested'),
                    icon: Icon(userRSVP == 'interested'
                        ? Icons.star
                        : Icons.star_border),
                    label: const Text('Interested'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          userRSVP == 'interested' ? Colors.orange[50] : null,
                      side: BorderSide(
                        color: userRSVP == 'interested'
                            ? Colors.orange
                            : Colors.grey,
                      ),
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: userRSVP == 'declined'
                        ? null
                        : () => _handleRSVP('declined'),
                    icon: Icon(userRSVP == 'declined'
                        ? Icons.cancel
                        : Icons.cancel_outlined),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          userRSVP == 'declined' ? Colors.red[50] : null,
                      side: BorderSide(
                        color:
                            userRSVP == 'declined' ? Colors.red : Colors.grey,
                      ),
                      minimumSize: const Size(0, 50),
                    ),
                  ),
                ),
              ],
            ),
            if (disableGoing && !onWaitlist && userRSVP != 'declined') ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _joinWaitlist,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Colors.orange[700] ?? Colors.orange),
                ),
                child: const Text('Join Waitlist'),
              ),
            ],
            if (userRSVP == 'going') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _checkIn,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Check In to Event'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _shareEvent() async {
    try {
      final url = 'https://freetalk.site/events/${widget.eventId}';
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event link copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to share: $e')),
        );
      }
    }
  }
}
