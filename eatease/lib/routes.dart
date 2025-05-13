import 'package:flutter/material.dart';

// Auth Screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';

// Admin Screens
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/user_management_screen.dart';

// Customer Screens
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/customer_main_screen.dart';
import 'screens/customer/profile_screen.dart';
import 'screens/customer/profile_navigation.dart';
import 'screens/customer/customer_orders_screen.dart';
import 'screens/customer/chat/customer_chat_screen.dart';

// Merchant Screens
import 'screens/merchant/merchant_home_screen.dart';
import 'screens/merchant/product_list_screen.dart';
import 'screens/merchant/product_form_screen.dart';
import 'screens/merchant/merchant_settings_screen.dart';
import 'screens/merchant/merchant_orders_screen.dart';
import 'screens/merchant/merchant_main_screen.dart';
import 'screens/merchant/merchant_chat_screen.dart';

// Shared Components 
import 'screens/shared/auth_wrapper.dart';

/// Route name constants to avoid string literals throughout the app
class AppRoutes {
  // Auth Routes
  static const String initial = '/';
  static const String login = '/login';
  static const String register = '/register';
  
  // User Role-Based Home Screens
  static const String home = '/home';
  static const String customer = '/customer';
  static const String merchant = '/merchant';
  static const String merchantHome = '/merchant/home';
  
  // Customer Routes
  static const String customerProfile = '/customer/profile';
  static const String customerOrders = '/customer/orders';
  static const String customerChat = '/customer/chat';
  
  // Merchant Routes
  static const String merchantProducts = '/merchant/products';
  static const String merchantProductsAdd = '/merchant/products/add';
  static const String merchantProductsEdit = '/merchant/products/edit';
  static const String merchantSettings = '/merchant/settings';
  static const String merchantOrders = '/merchant/orders';
  static const String merchantChat = '/merchant/chat';
  
  // Admin Routes
  static const String admin = '/admin';
  static const String adminSettings = '/admin/settings';
  static const String adminUsers = '/admin/users';
  
  // Log prefix for consistent logging
  static const String _logPrefix = '[ROUTES]';
}

// Application Routes
final Map<String, WidgetBuilder> appRoutes = {
  // Auth Routes
  AppRoutes.initial: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Auth Wrapper (${AppRoutes.initial})');
    return const AuthWrapper();
  },
  AppRoutes.login: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Login Screen (${AppRoutes.login})');
    return LoginScreen(onRegister: () => Navigator.pushReplacementNamed(context, AppRoutes.register));
  },
  AppRoutes.register: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Register Screen (${AppRoutes.register})');
    return RegisterScreen(onLogin: () => Navigator.pushReplacementNamed(context, AppRoutes.login));
  },
  
  // User Role-Based Home Screens
  AppRoutes.home: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Generic Home (${AppRoutes.home})');
    return const CustomerMainScreen(initialTab: 0);
  }, // Fallback home
  AppRoutes.customer: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Customer Home (${AppRoutes.customer})');
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final initialTab = args != null ? args['initialTab'] as int? ?? 0 : 0;
    return CustomerMainScreen(initialTab: initialTab);
  },
  AppRoutes.merchant: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Home (${AppRoutes.merchant})');
    return const MerchantMainScreen(initialTab: 0);
  }, 
  AppRoutes.merchantHome: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Home Alternative Route (${AppRoutes.merchantHome})');
    return const MerchantMainScreen(initialTab: 0);
  },
  
  // Customer Routes
  AppRoutes.customerProfile: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Customer Profile (${AppRoutes.customerProfile})');
    return const CustomerMainScreen(initialTab: 4);
  },
  AppRoutes.customerOrders: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Customer Orders (${AppRoutes.customerOrders})');
    return const CustomerMainScreen(initialTab: 2);
  },
  AppRoutes.customerChat: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Customer Chat (${AppRoutes.customerChat})');
    return const CustomerMainScreen(initialTab: 3);
  },
  
  // Merchant Routes
  AppRoutes.merchantProducts: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Products (${AppRoutes.merchantProducts})');
    return const MerchantMainScreen(initialTab: 1);
  },
  AppRoutes.merchantProductsAdd: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Add Product Form (${AppRoutes.merchantProductsAdd})');
    return const ProductFormScreen();
  },
  AppRoutes.merchantSettings: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Settings (${AppRoutes.merchantSettings})');
    return const MerchantMainScreen(initialTab: 4);
  },
  AppRoutes.merchantOrders: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Orders (${AppRoutes.merchantOrders})');
    return const MerchantMainScreen(initialTab: 2);
  },
  AppRoutes.merchantChat: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Chat (${AppRoutes.merchantChat})');
    return const MerchantChatScreen();
  },
  
  // Admin Routes
  AppRoutes.admin: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Admin Dashboard (${AppRoutes.admin})');
    return const AdminDashboard();
  },
  AppRoutes.adminSettings: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Admin Settings (${AppRoutes.adminSettings})');
    return const AdminSettingsScreen();
  },
  AppRoutes.adminUsers: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: User Management (${AppRoutes.adminUsers})');
    return const UserManagementScreen();
  },
};

/// Navigation Helper Functions
void navigateToRoleBasedHome(BuildContext context, String role) {
  print('${AppRoutes._logPrefix} ROUTING USER BY ROLE: $role at ${DateTime.now().toIso8601String()}');
  
  switch (role) {
    case 'admin':
      print('${AppRoutes._logPrefix} ROLE-BASED NAVIGATION: Routing admin to ${AppRoutes.admin}');
      Navigator.pushReplacementNamed(context, AppRoutes.admin);
      break;
    case 'merchant':
      print('${AppRoutes._logPrefix} ROLE-BASED NAVIGATION: Routing merchant to ${AppRoutes.merchant}');
      Navigator.pushReplacementNamed(context, AppRoutes.merchant);
      break;
    case 'customer':
    case 'user':
      print('${AppRoutes._logPrefix} ROLE-BASED NAVIGATION: Routing customer to ${AppRoutes.customer}');
      Navigator.pushReplacementNamed(context, AppRoutes.customer);
      break;
    default:
      print('${AppRoutes._logPrefix} ROLE-BASED NAVIGATION: Unknown role "$role", routing to ${AppRoutes.home}');
      Navigator.pushReplacementNamed(context, AppRoutes.home);
      break;
  }
} 