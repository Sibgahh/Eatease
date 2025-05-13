import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/user/user_model.dart';
import '../../models/merchant_model.dart';

class AuthService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Memory cache for storing data temporarily
  final Map<String, dynamic> _memoryCache = {};

  // Get current user
  auth.User? get currentUser => _auth.currentUser;

  // Get current user model
  Stream<UserModel?> get currentUserModel {
    if (currentUser == null) {
      return Stream.value(null);
    }
    
    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) {
            return null;
          }
          return UserModel.fromMap(snapshot.data()!, snapshot.id);
        });
  }

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        return null;
      }
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Sign up with email and password
  Future<auth.UserCredential> signUpWithEmailAndPassword(String email, String password, String displayName) async {
    try {
      // Create user with email and password
      auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user!.updateDisplayName(displayName);
      
      // Save user data to Firestore
      await _saveUserToFirestore(userCredential.user!, displayName);
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<auth.UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      // First authenticate with Firebase
      auth.UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check if user is banned/disabled in Firestore
      print("Checking if user is banned: ${result.user!.uid}");
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(result.user!.uid).get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        bool isActive = userData['isActive'] ?? true;
        
        if (!isActive) {
          print("User is banned, signing out");
          // If user is banned, sign them out immediately and throw an error
          await _auth.signOut();
          throw Exception('Your account has been disabled. Please contact admin for assistance.');
        }
      }
      
      // If not banned, update last login time
      await _firestore.collection('users').doc(result.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      
      return result;
    } catch (e) {
      print("Sign in error: $e");
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Save user to Firestore
  Future<void> _saveUserToFirestore(auth.User user, String displayName) async {
    print("Saving user to Firestore: ${user.uid}, displayName: $displayName");
    DateTime now = DateTime.now();
    
    UserModel newUser = UserModel(
      id: user.uid,
      email: user.email ?? '',
      displayName: displayName,
      phoneNumber: '',
      role: 'user',
      roles: ['user'],
      isActive: true,
      createdAt: now,
      lastLogin: now,
      photoURL: user.photoURL,
    );
    
    print("Created UserModel: role=${newUser.role}, roles=${newUser.roles}");
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(newUser.toMap());
    print("User data saved to Firestore");
  }

  // Create admin user (for initial setup)
  Future<void> createAdminUser(String email, String password, String displayName) async {
    try {
      // Create user with email and password
      auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user!.updateDisplayName(displayName);
      
      // Save as admin user with admin role
      DateTime now = DateTime.now();
      
      UserModel adminUser = UserModel(
        id: userCredential.user!.uid,
        email: userCredential.user!.email ?? '',
        displayName: displayName,
        phoneNumber: userCredential.user!.phoneNumber ?? '',
        role: 'admin',
        roles: ['admin', 'customer'],
        isActive: true,
        createdAt: now,
        lastLogin: now,
        photoURL: userCredential.user!.photoURL,
      );
      
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(adminUser.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Create user with specific role (for super admin use)
  Future<String> createUserWithRole(
    String email, 
    String password, 
    String displayName, 
    String phoneNumber,
    String role,
  ) async {
    try {
      print("[AUTH_SERVICE] Starting user creation process");
      print("[AUTH_SERVICE] Email: $email, Role: $role");
      
      // Validate role
      if (!['admin', 'merchant', 'customer', 'user'].contains(role)) {
        print("[AUTH_SERVICE] Invalid role: $role");
        throw Exception('Invalid role specified');
      }
      
      print("[AUTH_SERVICE] Creating user with Firebase Auth");
      // Create user with Firebase Auth
      auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (userCredential.user == null) {
        throw Exception('Failed to create user account');
      }
      
      print("[AUTH_SERVICE] User created with Firebase Auth: ${userCredential.user?.uid}");
      
      print("[AUTH_SERVICE] Updating display name");
      // Update display name
      await userCredential.user!.updateDisplayName(displayName);
      
      print("[AUTH_SERVICE] Saving user data to Firestore");
      // Save user with role to Firestore
      DateTime now = DateTime.now();
      
      UserModel newUser = UserModel(
        id: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        phoneNumber: phoneNumber,
        role: role,
        roles: [role],
        isActive: true,
        createdAt: now,
        lastLogin: now,
        photoURL: userCredential.user!.photoURL,
      );
      
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(newUser.toMap());
      
      print("[AUTH_SERVICE] User data saved to Firestore");
      
      // Ensure we're signed in
      if (_auth.currentUser == null) {
        print("[AUTH_SERVICE] User not signed in, signing in now");
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print("[AUTH_SERVICE] User signed in successfully");
      } else {
        print("[AUTH_SERVICE] User already signed in");
      }
      
      return userCredential.user!.uid;
    } catch (e) {
      print("[AUTH_SERVICE] Error creating user: $e");
      // If we created the user but failed later, try to clean up
      if (e is auth.FirebaseAuthException && e.code == 'email-already-in-use') {
        throw Exception('This email is already registered');
      }
      rethrow;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }
      
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return doc.exists && doc.data()?['role'] == 'admin';
    } catch (e) {
      print('Error checking if user is admin: $e');
      return false;
    }
  }

  // Get current user role
  Future<String> getUserRole() async {
    if (currentUser == null) {
      return 'customer'; // Default to customer if no user is logged in
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) {
        return 'customer';
      }
      
      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
      return userData.role;
    } catch (e) {
      print('Error getting user role: $e');
      return 'customer';
    }
  }

  // Check if user is merchant
  Future<bool> isMerchant() async {
    if (currentUser == null) {
      return false;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) {
        return false;
      }
      
      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
      return userData.isMerchant();
    } catch (e) {
      print('Error checking merchant status: $e');
      return false;
    }
  }

  // Get merchant model for the current user
  Future<MerchantModel?> getCurrentMerchantModel({bool forceRefresh = false}) async {
    if (currentUser == null) {
      return null;
    }
    
    try {
      // Create a cache key based on user ID and current time (for TTL-like behavior)
      final cacheKey = '${currentUser!.uid}_merchant';
      
      // Try to get cached data from in-memory cache
      final cachedData = _memoryCache[cacheKey];
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // If we have valid cached data that's less than 1 minute old and not forcing refresh, use it
      if (!forceRefresh &&
          cachedData != null && 
          cachedData['timestamp'] != null && 
          (currentTime - cachedData['timestamp'] < 60000)) {
        print('Returning merchant data from cache');
        return cachedData['data'] as MerchantModel?;
      }
      
      // Otherwise, fetch from Firestore
      print('Fetching merchant data from Firestore');
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) {
        print('User document does not exist in Firestore');
        return null;
      }
      
      final userData = userDoc.data()!;
      if (userData['role'] != 'merchant') {
        print('User is not a merchant');
        return null;
      }
      
      final merchantModel = MerchantModel.fromMap(userData, userDoc.id);
      print('Merchant data fetched, isStoreActive: ${merchantModel.isStoreActive}');
      
      // Cache the result
      _memoryCache[cacheKey] = {
        'data': merchantModel,
        'timestamp': currentTime,
      };
      
      return merchantModel;
    } catch (e) {
      print('Error getting merchant model: $e');
      return null;
    }
  }
  
  // Update merchant store information
  Future<bool> updateMerchantStore({
    required String storeName,
    String? storeDescription,
    String? storeAddress,
    String? phoneNumber,
  }) async {
    if (currentUser == null) {
      return false;
    }
    
    try {
      final userRef = _firestore.collection('users').doc(currentUser!.uid);
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        return false;
      }
      
      final updateData = <String, dynamic>{
        'storeName': storeName,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (storeDescription != null) {
        updateData['storeDescription'] = storeDescription;
      }
      
      if (storeAddress != null) {
        updateData['storeAddress'] = storeAddress;
      }
      
      if (phoneNumber != null) {
        updateData['phoneNumber'] = phoneNumber;
      }
      
      await userRef.update(updateData);
      return true;
    } catch (e) {
      print('Error updating merchant store: $e');
      return false;
    }
  }
  
  // Update merchant store active status (open/close store)
  Future<bool> updateMerchantStoreStatus(bool isActive) async {
    if (currentUser == null) {
      print('updateMerchantStoreStatus: No current user found');
      return false;
    }
    
    try {
      final userRef = _firestore.collection('users').doc(currentUser!.uid);
      print('updateMerchantStoreStatus: Attempting to update status to $isActive for user ${currentUser!.uid}');
      
      // First check if the document exists
      final userDoc = await userRef.get();
      
      if (!userDoc.exists) {
        print('updateMerchantStoreStatus: User document does not exist');
        return false;
      }
      
      // Update the document
      await userRef.update({
        'isStoreActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('updateMerchantStoreStatus: Successfully updated store status to $isActive in Firestore');
      
      // Update the in-memory cache
      final cacheKey = '${currentUser!.uid}_merchant';
      final cachedData = _memoryCache[cacheKey];
      if (cachedData != null && cachedData['data'] is MerchantModel) {
        final merchantModel = cachedData['data'] as MerchantModel;
        _memoryCache[cacheKey] = {
          'data': merchantModel.copyWith(isStoreActive: isActive),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
        print('updateMerchantStoreStatus: Updated in-memory cache');
      } else {
        print('updateMerchantStoreStatus: No cache to update or invalid cache data');
        // Invalidate the cache to force a fresh load next time
        _memoryCache.remove(cacheKey);
      }
      
      return true;
    } catch (e) {
      print('Error updating merchant store status: $e');
      return false;
    }
  }

  // Get current user's display name
  Future<String?> getCurrentUserName() async {
    if (currentUser == null) {
      return null;
    }
    
    try {
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) {
        return currentUser!.displayName;
      }
      
      final userData = userDoc.data()!;
      return userData['displayName'] as String? ?? currentUser!.displayName;
    } catch (e) {
      print('Error getting user name: $e');
      return currentUser!.displayName;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
} 