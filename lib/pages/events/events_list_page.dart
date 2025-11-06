import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/event_model.dart';
import '../../services/event_service.dart';
import '../../utils/event_utils.dart';
import '../../utils/auth_storage.dart';
import 'event_detail_page.dart';
import 'create_event_page.dart';

class EventsListPage extends StatefulWidget {
  const EventsListPage({super.key});

  @override
  State<EventsListPage> createState() => _EventsListPageState();
}

class _EventsListPageState extends State<EventsListPage>
    with SingleTickerProviderStateMixin {
  final EventService _eventService = EventService();
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Event> _myEvents = [];
  List<Event> _discoveredEvents = [];
  List<Event> _filteredMyEvents = [];
  List<Event> _filteredDiscoveredEvents = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreMyEvents = true;
  bool _hasMoreDiscoveredEvents = true;
  int _myEventsPage = 1;
  int _discoveredEventsPage = 1;
  String? _currentUserId;

  // Filter options
  String _selectedFilter = 'all'; // all, upcoming, ongoing, past
  final Set<String> _selectedTags = {};
  
  // Sorting options
  String _sortBy = 'date'; // date, attendance, popularity

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserId();
    _loadEvents();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    _currentUserId = await AuthStorage.getUserId();
    setState(() {});
  }

  Future<void> _loadEvents({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _myEventsPage = 1;
        _discoveredEventsPage = 1;
        _hasMoreMyEvents = true;
        _hasMoreDiscoveredEvents = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      if (refresh) {
        final myEvents = await _eventService.getMyEvents(page: _myEventsPage, limit: 20);
        final discovered = await _eventService.discoverEvents(page: _discoveredEventsPage, limit: 20);
        
        // Debug: Log event data to see what we're working with
        if (kDebugMode) {
          print('DEBUG: Loaded ${myEvents.length} my events');
          print('DEBUG: Loaded ${discovered.length} discovered events');
          for (int i = 0; i < myEvents.length; i++) {
            final event = myEvents[i];
            print('DEBUG: My Event $i: ${event.title}');
            print('DEBUG: - coverImage: ${event.coverImage}');
            print('DEBUG: - has coverImage: ${event.coverImage != null && event.coverImage!.isNotEmpty}');
          }
          for (int i = 0; i < discovered.length; i++) {
            final event = discovered[i];
            print('DEBUG: Discovered Event $i: ${event.title}');
            print('DEBUG: - coverImage: ${event.coverImage}');
            print('DEBUG: - has coverImage: ${event.coverImage != null && event.coverImage!.isNotEmpty}');
          }
        }
        
        setState(() {
          _myEvents = myEvents;
          _discoveredEvents = discovered;
          _hasMoreMyEvents = myEvents.length >= 20;
          _hasMoreDiscoveredEvents = discovered.length >= 20;
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading events: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreMyEvents() async {
    if (_isLoadingMore || !_hasMoreMyEvents) return;

    setState(() {
      _isLoadingMore = true;
      _myEventsPage++;
    });

    try {
      final newEvents = await _eventService.getMyEvents(page: _myEventsPage, limit: 20);
      setState(() {
        _myEvents.addAll(newEvents);
        _hasMoreMyEvents = newEvents.length >= 20;
        _isLoadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _myEventsPage--;
      });
    }
  }

  Future<void> _loadMoreDiscoveredEvents() async {
    if (_isLoadingMore || !_hasMoreDiscoveredEvents) return;

    setState(() {
      _isLoadingMore = true;
      _discoveredEventsPage++;
    });

    try {
      final newEvents = await _eventService.discoverEvents(page: _discoveredEventsPage, limit: 20);
      setState(() {
        _discoveredEvents.addAll(newEvents);
        _hasMoreDiscoveredEvents = newEvents.length >= 20;
        _isLoadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _discoveredEventsPage--;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMyEvents = _filterEvents(_myEvents, query);
      _filteredDiscoveredEvents = _filterEvents(_discoveredEvents, query);
    });
  }

  List<Event> _filterEvents(List<Event> events, String query) {
    var filtered = events;

    // Apply search query
    if (query.isNotEmpty) {
      filtered = filtered.where((event) {
        return event.title.toLowerCase().contains(query) ||
            event.description.toLowerCase().contains(query) ||
            event.tags.any((tag) => tag.toLowerCase().contains(query)) ||
            (event.locationName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply status filter
    if (_selectedFilter != 'all') {
      filtered = filtered.where((event) {
        final status = EventUtils.getEventStatus(event);
        switch (_selectedFilter) {
          case 'upcoming':
            return status == EventStatus.upcoming ||
                status == EventStatus.today;
          case 'ongoing':
            return status == EventStatus.ongoing;
          case 'past':
            return status == EventStatus.past;
          default:
            return true;
        }
      }).toList();
    }

    // Apply tag filter
    if (_selectedTags.isNotEmpty) {
      filtered = filtered.where((event) {
        return event.tags.any((tag) => _selectedTags.contains(tag));
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case 'attendance':
        filtered.sort((a, b) {
          final countA = a.rsvps.where((r) => r.status == 'going').length;
          final countB = b.rsvps.where((r) => r.status == 'going').length;
          return countB.compareTo(countA); // Descending
        });
        break;
      case 'popularity':
        filtered.sort((a, b) {
          final totalA = a.rsvps.length + (a.capacity != null ? a.capacity! - a.rsvps.where((r) => r.status == 'going').length : 0);
          final totalB = b.rsvps.length + (b.capacity != null ? b.capacity! - b.rsvps.where((r) => r.status == 'going').length : 0);
          return totalB.compareTo(totalA); // Descending
        });
        break;
      case 'date':
      default:
        // Sort by start time (upcoming first)
        filtered.sort((a, b) {
          final statusA = EventUtils.getEventStatus(a);
          final statusB = EventUtils.getEventStatus(b);

          // Ongoing events first
          if (statusA == EventStatus.ongoing && statusB != EventStatus.ongoing) {
            return -1;
          }
          if (statusB == EventStatus.ongoing && statusA != EventStatus.ongoing) {
            return 1;
          }

          // Today events next
          if (statusA == EventStatus.today && statusB != EventStatus.today) {
            return -1;
          }
          if (statusB == EventStatus.today && statusA != EventStatus.today) {
            return 1;
          }

          // Then sort by start time
          return a.startTime.compareTo(b.startTime);
        });
        break;
    }

    return filtered;
  }

  Set<String> _getAllTags() {
    final allEvents = [..._myEvents, ..._discoveredEvents];
    final tags = <String>{};
    for (var event in allEvents) {
      tags.addAll(event.tags);
    }
    return tags;
  }

  String? _getUserRSVPStatus(Event event) {
    if (_currentUserId == null) return null;
    try {
      final rsvp = event.rsvps.firstWhere(
        (r) => r.user == _currentUserId,
      );
      return rsvp.status;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortOptions,
            tooltip: 'Sort events',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search events...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ),
              // Filter chips
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildFilterChip('All', 'all'),
                    _buildFilterChip('Upcoming', 'upcoming'),
                    _buildFilterChip('Ongoing', 'ongoing'),
                    _buildFilterChip('Past', 'past'),
                    // Tag filter button
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.filter_list, size: 18),
                        label: Text(_selectedTags.isEmpty
                            ? 'Tags'
                            : '${_selectedTags.length} Tags'),
                        onPressed: _showTagFilter,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading && _myEvents.isEmpty && _discoveredEvents.isEmpty
          ? _buildLoadingSkeletons()
          : Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: 'My Events (${_filteredMyEvents.length})'),
                    Tab(text: 'Discover (${_filteredDiscoveredEvents.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEventList(_filteredMyEvents, _loadMoreMyEvents, _hasMoreMyEvents),
                      _buildEventList(_filteredDiscoveredEvents, _loadMoreDiscoveredEvents, _hasMoreDiscoveredEvents),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventPage()),
          );
          if (result == true) {
            _loadEvents();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
    );
  }

  Future<void> _showSortOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort Events',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date (Upcoming First)'),
              trailing: _sortBy == 'date'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(context, 'date'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Most Attended'),
              trailing: _sortBy == 'attendance'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(context, 'attendance'),
            ),
            ListTile(
              leading: const Icon(Icons.trending_up),
              title: const Text('Most Popular'),
              trailing: _sortBy == 'popularity'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => Navigator.pop(context, 'popularity'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result != _sortBy) {
      setState(() {
        _sortBy = result;
        _applyFilters();
      });
    }
  }

  Widget _buildLoadingSkeletons() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => const EventCardSkeleton(),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  Future<void> _showTagFilter() async {
    final allTags = _getAllTags().toList()..sort();

    await showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter by Tags',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_selectedTags.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModalState(() => _selectedTags.clear());
                        setState(() => _applyFilters());
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    avatar: Icon(EventUtils.getTagIcon(tag), size: 16),
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (selected) {
                      setModalState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                      setState(() => _applyFilters());
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventList(List<Event> events, VoidCallback loadMore, bool hasMore) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No events found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchController.text.isNotEmpty
                  ? 'Try adjusting your search or filters'
                  : 'Create an event to get started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadEvents(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: events.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Loading indicator for pagination
          if (index == events.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (hasMore) {
              // Trigger load more when approaching the end
              Future.microtask(loadMore);
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return const SizedBox.shrink();
          }

          final event = events[index];
          final status = EventUtils.getEventStatus(event);
          final userRSVP = _getUserRSVPStatus(event);

          return EventCard(
            event: event,
            status: status,
            userRSVP: userRSVP,
            currentUserId: _currentUserId,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailPage(eventId: event.id),
                ),
              );
              if (result == true) {
                _loadEvents();
              }
            },
            onShare: () => _shareEvent(event),
            onDelete: () => _deleteEvent(event),
          );
        },
      ),
    );
  }

  Future<void> _shareEvent(Event event) async {
    final text = 'Check out this event: ${event.title}\n\n${EventUtils.formatEventDate(event.startTime)}';
    await Share.share(text);
  }

  Future<void> _deleteEvent(Event event) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Deleting event...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await _eventService.deleteEvent(event.id);

      // Refresh events list
      await _loadEvents();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class EventCard extends StatelessWidget {
  final Event event;
  final EventStatus status;
  final String? userRSVP;
  final String? currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const EventCard({
    super.key,
    required this.event,
    required this.status,
    this.userRSVP,
    this.currentUserId,
    required this.onTap,
    this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final goingCount = event.rsvps.where((r) => r.status == 'going').length;
    final interestedCount =
        event.rsvps.where((r) => r.status == 'interested').length;
    final isAtCapacity = EventUtils.isAtCapacity(event);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image or placeholder
            Stack(
              children: [
                if (event.coverImage != null && event.coverImage!.isNotEmpty)
                  Builder(
                    builder: (context) {
                      // Decode URL-encoded characters in the image path
                      final decodedPath = Uri.decodeComponent(event.coverImage!);
                      
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
                        print('DEBUG: Original coverImage: ${event.coverImage}');
                        print('DEBUG: Decoded path: $decodedPath');
                        print('DEBUG: Final imageUrl: $imageUrl');
                      }
                      
                      return CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) {
                          if (kDebugMode) {
                            print('DEBUG: Image load error for URL: $url');
                            print('DEBUG: Error: $error');
                          }
                          return _buildPlaceholderImage();
                        },
                      );
                    },
                  )
                else
                  _buildPlaceholderImage(),

                // Status badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: EventUtils.getStatusColor(status),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      EventUtils.getStatusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

                // User RSVP badge
                if (userRSVP != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRSVPColor(userRSVP!),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getRSVPIcon(userRSVP!),
                              size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _getRSVPLabel(userRSVP!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Date/Time
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          EventUtils.formatEventDate(event.startTime),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Relative time
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          EventUtils.getRelativeTime(event.startTime),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  if (event.locationName != null) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.locationName!,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Attendance info
                  Row(
                    children: [
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        event.capacity != null
                            ? '$goingCount/${event.capacity} going'
                            : '$goingCount going',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (interestedCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '· $interestedCount interested',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                      if (isAtCapacity) ...[
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            'FULL',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Description
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      event.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],

                  // Tags and Action buttons
                  if (event.tags.isNotEmpty || onShare != null || onDelete != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (event.tags.isNotEmpty)
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: event.tags.take(2).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        EventUtils.getTagIcon(tag),
                                        size: 12,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (onShare != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
                            onPressed: onShare,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Share event',
                          ),
                        ],
                        if (onDelete != null && currentUserId != null && event.organizer == currentUserId) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => onDelete?.call(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete event',
                            color: Colors.red[600],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[300]!,
            Colors.purple[300]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event, size: 64, color: Colors.white70),
      ),
    );
  }

  Color _getRSVPColor(String status) {
    switch (status) {
      case 'going':
        return Colors.green[600]!;
      case 'interested':
        return Colors.orange[600]!;
      case 'declined':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getRSVPIcon(String status) {
    switch (status) {
      case 'going':
        return Icons.check_circle;
      case 'interested':
        return Icons.star;
      case 'declined':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getRSVPLabel(String status) {
    switch (status) {
      case 'going':
        return 'Going';
      case 'interested':
        return 'Interested';
      case 'declined':
        return 'Not Going';
      default:
        return status;
    }
  }
}

/// Skeleton loader for event cards
class EventCardSkeleton extends StatefulWidget {
  const EventCardSkeleton({super.key});

  @override
  State<EventCardSkeleton> createState() => _EventCardSkeletonState();
}

class _EventCardSkeletonState extends State<EventCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image skeleton
                Container(
                  height: 180,
                  color: Colors.grey[300],
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title skeleton
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date skeleton
                      Row(
                        children: [
                          Container(
                            height: 16,
                            width: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 16,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Attendance skeleton
                      Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Description skeleton
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
