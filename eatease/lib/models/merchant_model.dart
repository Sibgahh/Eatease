import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class MerchantModel extends UserModel {
  final String? storeName;
  final String? storeDescription;
  final String? storeAddress;
  final bool isStoreActive;
  final Map<String, dynamic>? businessHours;
  final List<String>? storeCategories;

  MerchantModel({
    required String id,
    required String email,
    required String displayName,
    String? photoURL,
    required String phoneNumber,
    required String role,
    List<String>? roles,
    bool isActive = true,
    required DateTime createdAt,
    DateTime? lastLogin,
    String? activeDeviceId,
    DateTime? lastDeviceLogin,
    this.storeName,
    this.storeDescription,
    this.storeAddress,
    this.isStoreActive = false,
    this.businessHours,
    this.storeCategories,
  }) : super(
          id: id,
          email: email,
          displayName: displayName,
          photoURL: photoURL,
          phoneNumber: phoneNumber,
          role: role,
          roles: roles,
          isActive: isActive,
          createdAt: createdAt,
          lastLogin: lastLogin,
          activeDeviceId: activeDeviceId,
          lastDeviceLogin: lastDeviceLogin,
        );

  factory MerchantModel.fromMap(Map<String, dynamic> map, String id) {
    return MerchantModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'] ?? '',
      role: map['role'] ?? 'merchant',
      roles: map['roles'] != null ? List<String>.from(map['roles']) : null,
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (map['lastLogin'] as Timestamp?)?.toDate(),
      activeDeviceId: map['activeDeviceId'],
      lastDeviceLogin: (map['lastDeviceLogin'] as Timestamp?)?.toDate(),
      storeName: map['storeName'],
      storeDescription: map['storeDescription'],
      storeAddress: map['storeAddress'],
      isStoreActive: map['isStoreActive'] ?? false,
      businessHours: map['businessHours'],
      storeCategories: map['storeCategories'] != null ? List<String>.from(map['storeCategories']) : null,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    Map<String, dynamic> baseMap = super.toMap();
    return {
      ...baseMap,
      'storeName': storeName,
      'storeDescription': storeDescription,
      'storeAddress': storeAddress,
      'isStoreActive': isStoreActive,
      'businessHours': businessHours,
      'storeCategories': storeCategories,
    };
  }

  @override
  MerchantModel copyWith({
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
    String? activeDeviceId,
    DateTime? lastDeviceLogin,
    String? storeName,
    String? storeDescription,
    String? storeAddress,
    bool? isStoreActive,
    Map<String, dynamic>? businessHours,
    List<String>? storeCategories,
  }) {
    return MerchantModel(
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
      activeDeviceId: activeDeviceId ?? this.activeDeviceId,
      lastDeviceLogin: lastDeviceLogin ?? this.lastDeviceLogin,
      storeName: storeName ?? this.storeName,
      storeDescription: storeDescription ?? this.storeDescription,
      storeAddress: storeAddress ?? this.storeAddress,
      isStoreActive: isStoreActive ?? this.isStoreActive,
      businessHours: businessHours ?? this.businessHours,
      storeCategories: storeCategories ?? this.storeCategories,
    );
  }

  bool isStoreConfigured() {
    // Check if the merchant has set up the required store information
    return storeName != null && 
           storeName!.isNotEmpty && 
           phoneNumber.isNotEmpty;
  }
} 