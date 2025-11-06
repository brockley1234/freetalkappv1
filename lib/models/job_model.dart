class Job {
  final String id;
  final String title;
  final String description;
  final String company;
  final String location;
  final String jobType;
  final String? salary;
  final String? requirements;
  final String? contactEmail;
  final String? contactPhone;
  final String? applicationUrl;
  final List<String> tags;
  final JobPoster postedBy;
  final bool isApproved;
  final bool isFlagged;
  final String? rejectionReason;
  final int views;
  final int applications;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Job({
    required this.id,
    required this.title,
    required this.description,
    required this.company,
    required this.location,
    required this.jobType,
    this.salary,
    this.requirements,
    this.contactEmail,
    this.contactPhone,
    this.applicationUrl,
    required this.tags,
    required this.postedBy,
    required this.isApproved,
    required this.isFlagged,
    this.rejectionReason,
    required this.views,
    required this.applications,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      company: json['company'] ?? '',
      location: json['location'] ?? '',
      jobType: json['jobType'] ?? 'full-time',
      salary: json['salary'],
      requirements: json['requirements'],
      contactEmail: json['contactEmail'],
      contactPhone: json['contactPhone'],
      applicationUrl: json['applicationUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      postedBy: json['postedBy'] is String
          ? JobPoster(id: json['postedBy'], name: 'Unknown', isVerified: false)
          : JobPoster.fromJson(json['postedBy']),
      isApproved: json['isApproved'] ?? true,
      isFlagged: json['isFlagged'] ?? false,
      rejectionReason: json['rejectionReason'],
      views: json['views'] ?? 0,
      applications: json['applications'] ?? 0,
      expiresAt:
          json['expiresAt'] != null ? DateTime.parse(json['expiresAt']) : null,
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'company': company,
      'location': location,
      'jobType': jobType,
      'salary': salary,
      'requirements': requirements,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'applicationUrl': applicationUrl,
      'tags': tags,
      'postedBy': postedBy.toJson(),
      'isApproved': isApproved,
      'isFlagged': isFlagged,
      'rejectionReason': rejectionReason,
      'views': views,
      'applications': applications,
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  String getJobTypeDisplay() {
    switch (jobType) {
      case 'full-time':
        return 'Full-time';
      case 'part-time':
        return 'Part-time';
      case 'contract':
        return 'Contract';
      case 'freelance':
        return 'Freelance';
      case 'internship':
        return 'Internship';
      case 'remote':
        return 'Remote';
      default:
        return jobType;
    }
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  // Get days until expiration
  int? get daysUntilExpiration {
    if (expiresAt == null) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  // Check if job is expiring soon (within 3 days)
  bool get isExpiringsoon {
    final daysLeft = daysUntilExpiration;
    if (daysLeft == null) return false;
    return daysLeft >= 0 && daysLeft <= 3;
  }

  // Format description for display (with paragraphs)
  String getFormattedDescription() {
    return description.replaceAll('\n', '\n\n');
  }

  // Get engagement rate
  double get engagementRate {
    if (views == 0) return 0;
    return (applications / views) * 100;
  }

  // Get job posting age in days
  int get ageInDays {
    return DateTime.now().difference(createdAt).inDays;
  }

  // Check if job is freshly posted (within 24 hours)
  bool get isFresh {
    return ageInDays == 0;
  }
}

class JobPoster {
  final String id;
  final String name;
  final String? profilePicture;
  final bool isVerified;
  final String? email;

  JobPoster({
    required this.id,
    required this.name,
    this.profilePicture,
    required this.isVerified,
    this.email,
  });

  factory JobPoster.fromJson(Map<String, dynamic> json) {
    return JobPoster(
      id: json['_id'] ?? json['id'],
      name: json['name'] ?? 'Unknown',
      profilePicture: json['profilePicture'],
      isVerified: json['isVerified'] ?? false,
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'profilePicture': profilePicture,
      'isVerified': isVerified,
      'email': email,
    };
  }
}
