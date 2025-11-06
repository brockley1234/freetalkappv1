class Event {
  final String id;
  final String title;
  final String description;
  final String organizer;
  final String? organizerName; // Populated organizer name
  final String? organizerAvatar; // Populated organizer avatar
  final DateTime startTime;
  final DateTime? endTime;
  final String timezone;
  final bool isAllDay;
  final String visibility;
  final String? coverImage;
  final int? capacity;
  final bool allowGuests;
  final List<String> tags;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final String? eventCode;
  final List<RSVP> rsvps;
  final List<Invitation> invitations;
  final List<CheckIn> checkIns;
  final List<String> waitlist;
  final int attendeesCount;
  final bool isApproved;
  final String? rejectionReason;
  final bool isFlagged;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.organizer,
    this.organizerName,
    this.organizerAvatar,
    required this.startTime,
    this.endTime,
    required this.timezone,
    required this.isAllDay,
    required this.visibility,
    this.coverImage,
    this.capacity,
    required this.allowGuests,
    required this.tags,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.eventCode,
    required this.rsvps,
    required this.invitations,
    required this.checkIns,
    required this.waitlist,
    required this.attendeesCount,
    required this.isApproved,
    this.rejectionReason,
    required this.isFlagged,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    // Extract organizer info if populated
    String organizerId;
    String? organizerName;
    String? organizerAvatar;
    
    if (json['organizer'] is String) {
      organizerId = json['organizer'];
    } else if (json['organizer'] is Map) {
      organizerId = json['organizer']?['_id'] ?? '';
      organizerName = json['organizer']?['name'] ?? json['organizer']?['username'];
      organizerAvatar = json['organizer']?['avatar'];
    } else {
      organizerId = '';
    }
    
    return Event(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      organizer: organizerId,
      organizerName: organizerName,
      organizerAvatar: organizerAvatar,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      timezone: json['timezone'] ?? 'UTC',
      isAllDay: json['isAllDay'] ?? false,
      visibility: json['visibility'] ?? 'public',
      coverImage: json['coverImage'],
      capacity: json['capacity'],
      allowGuests: json['allowGuests'] ?? true,
      tags: List<String>.from(json['tags'] ?? []),
      locationName: json['locationName'],
      locationAddress: json['locationAddress'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      eventCode: json['eventCode'],
      rsvps:
          (json['rsvps'] as List?)?.map((r) => RSVP.fromJson(r)).toList() ?? [],
      invitations: (json['invitations'] as List?)
              ?.map((i) => Invitation.fromJson(i))
              .toList() ??
          [],
      checkIns: (json['checkIns'] as List?)
              ?.map((c) => CheckIn.fromJson(c))
              .toList() ??
          [],
      waitlist: List<String>.from(json['waitlist'] ?? []),
      attendeesCount: json['attendeesCount'] ?? 0,
      isApproved: json['isApproved'] ?? true,
      rejectionReason: json['rejectionReason'],
      isFlagged: json['isFlagged'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizer': organizer,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'timezone': timezone,
      'isAllDay': isAllDay,
      'visibility': visibility,
      'coverImage': coverImage,
      'capacity': capacity,
      'allowGuests': allowGuests,
      'tags': tags,
      'locationName': locationName,
      'locationAddress': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'eventCode': eventCode,
      'attendeesCount': attendeesCount,
      'isApproved': isApproved,
      'rejectionReason': rejectionReason,
      'isFlagged': isFlagged,
    };
  }
}

class RSVP {
  final String user;
  final String status; // going, interested, declined
  final DateTime respondedAt;

  RSVP({
    required this.user,
    required this.status,
    required this.respondedAt,
  });

  factory RSVP.fromJson(Map<String, dynamic> json) {
    return RSVP(
      user: json['user'] is String ? json['user'] : json['user']?['_id'] ?? '',
      status: json['status'] ?? '',
      respondedAt: DateTime.parse(json['respondedAt']),
    );
  }
}

class Invitation {
  final String user;
  final String status; // pending, accepted, declined
  final DateTime invitedAt;
  final DateTime? respondedAt;

  Invitation({
    required this.user,
    required this.status,
    required this.invitedAt,
    this.respondedAt,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      user: json['user'] is String ? json['user'] : json['user']?['_id'] ?? '',
      status: json['status'] ?? 'pending',
      invitedAt: DateTime.parse(json['invitedAt']),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }
}

class CheckIn {
  final String user;
  final DateTime time;
  final String method; // qr, code, manual, geo
  final String? locationName;

  CheckIn({
    required this.user,
    required this.time,
    required this.method,
    this.locationName,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      user: json['user'] is String ? json['user'] : json['user']?['_id'] ?? '',
      time: DateTime.parse(json['time']),
      method: json['method'] ?? 'code',
      locationName: json['locationName'],
    );
  }
}
