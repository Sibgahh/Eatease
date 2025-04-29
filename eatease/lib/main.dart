import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'services/auth_service.dart';
import 'routes.dart';

// Add RouteObserver to track navigation
class NavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('[NAVIGATION] Pushed to ${route.settings.name ?? 'unknown route'} at ${DateTime.now().toIso8601String()}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('[NAVIGATION] Popped to ${previousRoute?.settings.name ?? 'unknown route'} at ${DateTime.now().toIso8601String()}');
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    print('[NAVIGATION] Replaced ${oldRoute?.settings.name ?? 'unknown route'} with ${newRoute?.settings.name ?? 'unknown route'} at ${DateTime.now().toIso8601String()}');
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    print('[NAVIGATION] Removed ${route.settings.name ?? 'unknown route'} at ${DateTime.now().toIso8601String()}');
    super.didRemove(route, previousRoute);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('[APP] Initializing Firebase at ${DateTime.now().toIso8601String()}');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('[APP] Firebase initialized at ${DateTime.now().toIso8601String()}');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('[APP] Building main MaterialApp at ${DateTime.now().toIso8601String()}');
    return MaterialApp(
      title: 'EatEase',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // Register the NavigationObserver
      navigatorObservers: [NavigationObserver()],
      initialRoute: AppRoutes.initial,
      routes: appRoutes,
      onUnknownRoute: (settings) {
        print('[APP] Unknown route: ${settings.name}, redirecting to initial route at ${DateTime.now().toIso8601String()}');
        return MaterialPageRoute(
          settings: RouteSettings(name: AppRoutes.initial),
          builder: (context) => appRoutes[AppRoutes.initial]!(context),
        );
      },
    );
  }
}
