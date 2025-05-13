import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'services/auth/auth_service.dart';
import 'services/product_service.dart';
import 'services/cleanup_service.dart';
import 'services/connectivity_service.dart';
import 'utils/app_theme.dart';
import 'routes.dart';
import 'widgets/connectivity_wrapper.dart';
import 'services/chat_service.dart';

// Custom page transition with no animation for customer pages
class NoAnimationPageTransition extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Return the child directly without animation
    return child;
  }
}

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
  
  try {
    // Initialize connectivity service first
    print('[APP] Initializing ConnectivityService');
    ConnectivityService().initialize();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    print('[APP] Firebase initialized at ${DateTime.now().toIso8601String()}');
    
    // Explicitly initialize Firebase Storage to ensure it's available
    final storage = FirebaseStorage.instance;
    print('[APP] Firebase Storage initialized with bucket: ${storage.bucket}');
    
    // Test Firebase Storage connection
    await _testFirebaseStorage();
    
    // Initialize Firestore settings for better performance
    FirebaseFirestore.instance.settings = 
        const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
    
    // Initialize the cleanup service to handle expiring conversations
    print('[APP] Starting cleanup service');
    CleanupService().startPeriodicCleanup(
      checkInterval: const Duration(minutes: 15), // Check every 15 minutes
    );
    
    // Update existing chat conversations with new fields
    print('[APP] Updating chat conversations data model');
    await ChatService().updateExistingConversations();
    
    runApp(const MyApp());
  } catch (e) {
    print('[APP] ERROR initializing Firebase: $e');
    
    // Show error dialog if initialization fails
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Firebase Initialization Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text('Error details: $e'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Restart the app
                    main();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

Future<void> _testFirebaseStorage() async {
  try {
    print('[APP] Testing Firebase Storage connection...');
    
    // Test basic connection by getting root reference metadata
    final storageRef = FirebaseStorage.instance.ref();
    
    try {
      // Try to get metadata for the root reference
      await storageRef.getMetadata();
      print('[APP] Successfully connected to Firebase Storage root');
    } catch (e) {
      print('[APP] Firebase Storage root metadata error: $e');
    }
    
    // Test bucket name
    print('[APP] Firebase Storage bucket name: ${FirebaseStorage.instance.bucket}');
    
    // Test creating a reference to products folder
    final productsRef = storageRef.child('products');
    print('[APP] Created reference to products folder: ${productsRef.fullPath}');
    
    // Create a test file
    final testRef = storageRef.child('test_file.txt');
    print('[APP] Testing upload capability with: ${testRef.fullPath}');
    
    try {
      // Try to create a small test file in the root
      final bytes = Uint8List.fromList(utf8.encode('Test file'));
      final uploadTask = testRef.putData(bytes);
      await uploadTask;
      print('[APP] Test file upload successful');
      
      // Get download URL to verify it worked
      final downloadUrl = await testRef.getDownloadURL();
      print('[APP] Test file download URL: $downloadUrl');
      
      // Clean up test file
      await testRef.delete();
      print('[APP] Test file deleted');
    } catch (e) {
      print('[APP] Test file upload failed: $e');
      if (e is FirebaseException) {
        print('[APP] Firebase error code: ${e.code}, message: ${e.message}');
      }
    }
    
    // Also test the ProductService
    final productService = ProductService();
    final connectionSuccess = await productService.testStorageConnection();
    print('[APP] ProductService storage connection test: ${connectionSuccess ? 'SUCCESS' : 'FAILED'}');
    
  } catch (e) {
    print('[APP] Firebase Storage test error: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitializing = true;
    });
    
    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      print('[APP] Firebase initialized at ${DateTime.now()}');
      
      // Migrate chat conversations data
      final chatService = ChatService();
      await chatService.updateExistingConversations();
      
    } catch (e, stackTrace) {
      print('[APP] Error initializing Firebase: $e');
      print(stackTrace);
    }
    
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('[APP] Building main MaterialApp at ${DateTime.now().toIso8601String()}');
    
    // Get the base theme data from AppTheme
    final baseTheme = AppTheme.getThemeData(context);
    
    // Add the page transitions theme to the base theme
    final customTheme = baseTheme.copyWith(
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          // Use the NoAnimationPageTransition for all platforms
          TargetPlatform.android: NoAnimationPageTransition(),
          TargetPlatform.iOS: NoAnimationPageTransition(),
          TargetPlatform.fuchsia: NoAnimationPageTransition(),
          TargetPlatform.linux: NoAnimationPageTransition(),
          TargetPlatform.macOS: NoAnimationPageTransition(),
          TargetPlatform.windows: NoAnimationPageTransition(),
        },
      ),
    );
    
    return ConnectivityWrapper(
      child: MaterialApp(
        title: 'EatEase',
        theme: customTheme,
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
      ),
    );
  }
}
  