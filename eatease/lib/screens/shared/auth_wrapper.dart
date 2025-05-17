import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/device_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../../routes.dart';
import '../customer/customer_home_screen.dart';
import '../merchant/merchant_main_screen.dart';
import '../admin/admin_dashboard.dart';
import 'package:eatease/utils/app_theme.dart';
import '../../widgets/connectivity_wrapper.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool isLogin = true;
  final ConnectivityService _connectivityService = ConnectivityService();
  final AuthService _authService = AuthService();

  void toggleView() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConnectivityWrapper(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          print("[AUTH_WRAPPER] Auth state changed: ${userSnapshot.connectionState}");
          
          // Show loading indicator while checking auth state
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If user is not logged in, show login/register screen
          if (!userSnapshot.hasData || userSnapshot.data == null) {
            print("[AUTH_WRAPPER] No user logged in, showing auth screen");
            return isLogin
                ? LoginScreen(onRegister: toggleView)
                : RegisterScreen(onLogin: toggleView);
          }

          // User is logged in, determine role and navigate
          print("[AUTH_WRAPPER] User logged in: ${userSnapshot.data!.uid}");
          return FutureBuilder<String>(
            future: _determineHomeRoute(_authService),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                print("[AUTH_WRAPPER] Error determining route: ${snapshot.error}");
                return Scaffold(
                  body: Center(
                    child: Text('Error: ${snapshot.error}'),
                  ),
                );
              }

              final route = snapshot.data ?? AppRoutes.customer;
              print("[AUTH_WRAPPER] Navigating to route: $route");
              
              return Navigator(
                onGenerateRoute: (settings) {
                  Widget page;
                  switch (route) {
                    case AppRoutes.admin:
                      page = const AdminDashboard();
                      break;
                    case AppRoutes.merchant:
                      page = const MerchantMainScreen();
                      break;
                    default:
                      page = const CustomerHomeScreen();
                  }
                  return MaterialPageRoute(builder: (context) => page);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _determineHomeRoute(AuthService authService) async {
    print("[AUTH_WRAPPER] Determining home route based on user role");
    
    if (await authService.isAdmin()) {
      print("[AUTH_WRAPPER] User is an admin, routing to admin dashboard");
      return AppRoutes.admin;
    }
    
    if (await authService.isMerchant()) {
      print("[AUTH_WRAPPER] User is a merchant, routing to merchant home");
      return AppRoutes.merchant;
    }
    
    print("[AUTH_WRAPPER] User is a customer, routing to customer home");
    return AppRoutes.customer;
  }
} 