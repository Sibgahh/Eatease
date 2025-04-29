import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user/user_model.dart';

class AuthService {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      // Validate role
      if (!['admin', 'merchant', 'customer', 'user'].contains(role)) {
        throw Exception('Invalid role specified');
      }
      
      // Create user with Firebase Auth
      auth.UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user!.updateDisplayName(displayName);
      
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
      
      return userCredential.user!.uid;
    } catch (e) {
      rethrow;
    }
  }

  // Check if user is admin
  Future<bool> isAdmin() async {
    print("Checking if user is admin...");
    if (currentUser == null) {
      print("Current user is null, not an admin");
      return false;
    }
    
    try {
      print("Fetching user document for ${currentUser!.uid}");
      final userDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
      if (!userDoc.exists) {
        print("User document does not exist");
        return false;
      }
      
      final userData = UserModel.fromMap(userDoc.data()!, userDoc.id);
      
      // Check if the user is an active admin or has admin role in their roles array
      bool isActiveAdmin = userData.role == 'admin';
      bool hasAdminRole = userData.roles?.contains('admin') ?? false;
      
      print("User active role: ${userData.role}, roles: ${userData.roles}, isAdmin: ${isActiveAdmin || hasAdminRole}");
      
      return isActiveAdmin || hasAdminRole;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
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
} 