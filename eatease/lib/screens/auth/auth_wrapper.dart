import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print("Building AuthWrapper");
    
    final AuthService authService = AuthService();
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print("Auth state change detected: ${snapshot.hasData ? 'User signed in' : 'No user'}");
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return FutureBuilder<String>(
            future: _determineHomeRoute(authService),
            builder: (context, routeSnapshot) {
              if (routeSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final route = routeSnapshot.data ?? '/';
              print("Navigating to route: $route");
              
              // Use Future.microtask to avoid build-time navigation
              Future.microtask(() {
                Navigator.pushReplacementNamed(context, route);
              });
              
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            },
          );
        } else {
          print("No user signed in, showing login/register screen");
          return _buildLoginRegisterPrompt(context);
        }
      },
    );
  }
  
  Widget _buildLoginRegisterPrompt(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to EatEase',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Login'),
            ),
            const SizedBox(height: 10.0),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/register');
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<String> _determineHomeRoute(AuthService authService) async {
    print("Determining home route based on user role");
    
    if (await authService.isAdmin()) {
      print("User is an admin, routing to admin dashboard");
      return '/admin';
    }
    
    if (await authService.isMerchant()) {
      print("User is a merchant, routing to merchant home");
      return '/merchant';
    }
    
    print("User is a customer, routing to customer home");
    return '/customer';
  }
} 