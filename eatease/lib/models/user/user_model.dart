import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoURL;
  final String phoneNumber;
  final String role;
  final List<String>? roles;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.phoneNumber,
    required this.role,
    this.roles,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? 'user',
      roles: map['roles'] != null ? List<String>.from(map['roles']) : null,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'role': role,
      'roles': roles,
      'isActive': isActive,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    String? phoneNumber,
    String? role,
    List<String>? roles,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  bool isAdmin() {
    bool primaryRoleIsAdmin = role == 'admin';
    bool hasAdminRole = roles?.contains('admin') ?? false;
    bool result = primaryRoleIsAdmin || hasAdminRole;
    print("isAdmin check: role=$role, roles=$roles, isAdmin=$result");
    return result;
  }

  bool isMerchant() {
    return role == 'merchant';
  }

  bool isCustomer() {
    return role == 'customer' || role == 'user';
  }
} 