import 'package:cloud_firestore/cloud_firestore.dart';

class JobHistoryItem {
  final String id;
  final String title;
  final String description;
  final DateTime completedAt;
  final double? rating;
  final String? review;

  JobHistoryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.completedAt,
    this.rating,
    this.review,
  });

  factory JobHistoryItem.fromMap(Map<String, dynamic> data) {
    return JobHistoryItem(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      completedAt:
          (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rating: data['rating']?.toDouble(),
      review: data['review'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completedAt': Timestamp.fromDate(completedAt),
      'rating': rating,
      'review': review,
    };
  }
}

class UserProfileModel {
  final String id;
  final String displayName;
  final String email;
  final String? avatar;
  final String userType;
  final String? tradeType;
  final String? phone;
  final String? bio;
  final double ratings;
  final int reviewCount;
  final List<JobHistoryItem> jobHistory;
  final bool isBlocked;
  final List<String> blockedUsers;
  final DateTime? lastSeen;
  final bool isOnline;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? additionalData;

  UserProfileModel({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatar,
    required this.userType,
    this.tradeType,
    this.phone,
    this.bio,
    this.ratings = 0.0,
    this.reviewCount = 0,
    this.jobHistory = const [],
    this.isBlocked = false,
    this.blockedUsers = const [],
    this.lastSeen,
    this.isOnline = false,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
    this.additionalData,
  });

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    List<JobHistoryItem> jobHistoryList = [];
    if (data['jobHistory'] != null) {
      jobHistoryList = (data['jobHistory'] as List)
          .map((item) => JobHistoryItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return UserProfileModel(
      id: doc.id,
      displayName: data['displayName'] ?? data['name'] ?? '',
      email: data['email'] ?? '',
      avatar: data['avatar'],
      userType: data['userType'] ?? '',
      tradeType: data['tradeType'],
      phone: data['phone'],
      bio: data['bio'],
      ratings: (data['ratings'] ?? 0.0).toDouble(),
      reviewCount: data['reviewCount'] ?? 0,
      jobHistory: jobHistoryList,
      isBlocked: data['isBlocked'] ?? false,
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] ?? false,
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      additionalData: Map<String, dynamic>.from(data)
        ..removeWhere(
          (key, value) => [
            'displayName',
            'name',
            'email',
            'avatar',
            'userType',
            'tradeType',
            'phone',
            'bio',
            'ratings',
            'reviewCount',
            'jobHistory',
            'isBlocked',
            'blockedUsers',
            'lastSeen',
            'isOnline',
            'isVerified',
            'createdAt',
            'updatedAt',
          ].contains(key),
        ),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'displayName': displayName,
      'email': email,
      'avatar': avatar,
      'userType': userType,
      'tradeType': tradeType,
      'phone': phone,
      'bio': bio,
      'ratings': ratings,
      'reviewCount': reviewCount,
      'jobHistory': jobHistory.map((item) => item.toMap()).toList(),
      'isBlocked': isBlocked,
      'blockedUsers': blockedUsers,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'isOnline': isOnline,
      'isVerified': isVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };

    if (additionalData != null) {
      data.addAll(additionalData!);
    }

    return data;
  }

  UserProfileModel copyWith({
    String? id,
    String? displayName,
    String? email,
    String? avatar,
    String? userType,
    String? tradeType,
    String? phone,
    String? bio,
    double? ratings,
    int? reviewCount,
    List<JobHistoryItem>? jobHistory,
    bool? isBlocked,
    List<String>? blockedUsers,
    DateTime? lastSeen,
    bool? isOnline,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      userType: userType ?? this.userType,
      tradeType: tradeType ?? this.tradeType,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
      ratings: ratings ?? this.ratings,
      reviewCount: reviewCount ?? this.reviewCount,
      jobHistory: jobHistory ?? this.jobHistory,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  // Helper getters
  bool get isHomeowner => userType == 'homeowner';
  bool get isTradie => userType == 'tradie';

  String get formattedRating {
    if (reviewCount == 0) return 'No ratings yet';
    return '${ratings.toStringAsFixed(1)} ($reviewCount reviews)';
  }

  String get statusText {
    if (isOnline) return 'Online';
    if (lastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(lastSeen!);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return 'Last seen ${lastSeen!.day}/${lastSeen!.month}/${lastSeen!.year}';
      }
    }
    return 'Offline';
  }

  int get completedJobsCount => jobHistory.length;

  double get averageRating => ratings;
}
