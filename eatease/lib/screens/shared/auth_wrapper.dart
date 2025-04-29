import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../../routes.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLogin = true;
  final String _logPrefix = '[AUTH_WRAPPER]';

  void toggleView() {
    print("$_logPrefix Toggling between login and register views");
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  void initState() {
    super.initState();
    print("$_logPrefix initState called at ${DateTime.now().toIso8601String()}");
  }

  @override
  Widget build(BuildContext context) {
    print("$_logPrefix Building AuthWrapper at ${DateTime.now().toIso8601String()}");
    final AuthService authService = AuthService();
    
    // Check if user is already signed in
    if (authService.currentUser != null) {
      final user = authService.currentUser!;
      print("$_logPrefix User is already signed in: ${user.email} (UID: ${user.uid})");
      
      // Check if the signed in user is banned
      return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            print("$_logPrefix Waiting for user data from Firestore at ${DateTime.now().toIso8601String()}");
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (userSnapshot.hasError) {
            print("$_logPrefix Error fetching user data: ${userSnapshot.error}");
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Error loading user data', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        print("$_logPrefix User clicked sign out after error");
                        authService.signOut();
                        Navigator.pushReplacementNamed(context, AppRoutes.login);
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Check if user document exists
          if (userSnapshot.hasData && userSnapshot.data!.exists) {
            print("$_logPrefix User document exists in Firestore");
            Map<String, dynamic> userData = userSnapshot.data!.data() as Map<String, dynamic>;
            bool isActive = userData['isActive'] ?? true;
            
            if (!isActive) {
              print("$_logPrefix User is banned, signing out user: ${user.email}");
              // If user is banned, sign them out and show login screen
              authService.signOut();
              
              // Show banned message and return to login
              WidgetsBinding.instance.addPostFrameCallback((_) {
                print("$_logPrefix Showing banned message at ${DateTime.now().toIso8601String()}");
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your account has been disabled. Please contact admin for assistance.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              });
              
              return LoginScreen(onRegister: toggleView);
            }
            
            // Get user role from Firestore document
            final String userRole = userData['role'] ?? 'user';
            print("$_logPrefix User role detected: $userRole for user: ${user.email}");
            
            // Log additional user information for debugging
            final List<dynamic> userRoles = userData['roles'] ?? [userRole];
            print("$_logPrefix User roles array: $userRoles");
            print("$_logPrefix User display name: ${userData['displayName']}");
            print("$_logPrefix User email: ${userData['email']}");
            
            // Delayed navigation to avoid build during build error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              print("$_logPrefix Starting role-based navigation for $userRole at ${DateTime.now().toIso8601String()}");
              navigateToRoleBasedHome(context, userRole);
            });
            
            // Return loading screen until navigation happens
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Redirecting to dashboard...'),
                  ],
                ),
              ),
            );
          } else {
            // Firestore doc doesn't exist for user - show login
            print("$_logPrefix User document doesn't exist for UID: ${user.uid}, signing out");
            authService.signOut();
            return LoginScreen(onRegister: toggleView);
          }
        },
      );
    } else {
      print("$_logPrefix No user signed in, showing ${isLogin ? 'login' : 'register'} screen");
      if (isLogin) {
        return LoginScreen(onRegister: toggleView);
      } else {
        return RegisterScreen(onLogin: toggleView);
      }
    }
  }
} 