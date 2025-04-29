import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import '../services/auth_service.dart';

/// Utility function to create an initial admin user
/// This should be run once to set up the first admin user
Future<void> createInitialAdmin() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  try {
    final AuthService authService = AuthService();
    
    // Create the admin user
    await authService.createAdminUser(
      'admin@eatease.com',  // Replace with actual admin email
      'Admin123!',          // Replace with secure password
      'Super Admin',        // Replace with admin name
    );
    
    print('Admin user created successfully!');
  } catch (e) {
    print('Error creating admin user: $e');
  }
}

/// Sample usage in a command-line app:
/// 
/// void main() async {
///   await createInitialAdmin();
/// } 