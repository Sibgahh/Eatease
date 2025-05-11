import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth/auth_service.dart';
import '../../services/connectivity_service.dart';
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

  void toggleView() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
            );
          }
          
        if (!userSnapshot.hasData || userSnapshot.data == null) {
          return ConnectivityWrapper(
            child: MaterialApp(
              theme: AppTheme.getThemeData(context),
              home: LoginScreen(onRegister: toggleView),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userSnapshot.data!.uid)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(),
              ),
            );
          }
          
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return ConnectivityWrapper(
                child: MaterialApp(
                  theme: AppTheme.getThemeData(context),
                  home: LoginScreen(onRegister: toggleView),
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final role = userData['role'] as String? ?? 'customer';

            // Load favorites for customer users
            if (role == 'customer') {
              FirebaseFirestore.instance
                  .collection('userFavorites')
                  .doc(userSnapshot.data!.uid)
                  .get()
                  .then((doc) {
                if (doc.exists) {
                  final favorites = List<String>.from(doc.data()?['favorites'] ?? []);
                  CustomerHomeScreen.favoritesNotifier.value = favorites.toSet();
                }
              }).catchError((error) {
                debugPrint('Error loading favorites: $error');
              });
            }

            Widget homeScreen;
            switch (role.toLowerCase()) {
              case 'customer':
                homeScreen = const CustomerHomeScreen();
                break;
              case 'merchant':
                homeScreen = const MerchantMainScreen(initialTab: 0);
                break;
              case 'admin':
                homeScreen = const AdminDashboard();
                break;
              default:
                homeScreen = LoginScreen(onRegister: toggleView);
          }

            return ConnectivityWrapper(
              child: MaterialApp(
                theme: AppTheme.getThemeData(context, role: role),
                home: homeScreen,
              ),
            );
          },
        );
      },
    );
  }
} 