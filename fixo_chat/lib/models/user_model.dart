import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String userType; // 'homeowner' or 'tradie'
  final String? tradeType; // Only for tradies
  final String? phone;
  final String? avatar;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.userType,
    this.tradeType,
    this.phone,
    this.avatar,
    this.bio,
    this.createdAt,
    this.updatedAt,
    this.additionalData,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      userType: data['userType'] ?? '',
      tradeType: data['tradeType'],
      phone: data['phone'],
      avatar: data['avatar'],
      bio: data['bio'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      additionalData: Map<String, dynamic>.from(data)
        ..removeWhere(
          (key, value) => [
            'name',
            'email',
            'userType',
            'tradeType',
            'phone',
            'avatar',
            'bio',
            'createdAt',
            'updatedAt',
          ].contains(key),
        ),
    );
  }

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'userType': userType,
      'phone': phone,
      'avatar': avatar,
      'bio': bio,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };

    if (tradeType != null) {
      data['tradeType'] = tradeType;
    }

    if (additionalData != null) {
      data.addAll(additionalData!);
    }

    return data;
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? userType,
    String? tradeType,
    String? phone,
    String? avatar,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      tradeType: tradeType ?? this.tradeType,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      additionalData: additionalData ?? this.additionalData,
    );
  }

  String get displayName => name.isNotEmpty ? name : email;

  bool get isHomeowner => userType == 'homeowner';
  bool get isTradie => userType == 'tradie';
}
