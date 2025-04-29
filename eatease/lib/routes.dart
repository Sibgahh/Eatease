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

// Merchant Screens
import 'screens/merchant/merchant_home_screen.dart';
import 'screens/merchant/product_list_screen.dart';
import 'screens/merchant/product_form_screen.dart';

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
  
  // Merchant Routes
  static const String merchantProducts = '/merchant/products';
  static const String merchantProductsAdd = '/merchant/products/add';
  static const String merchantProductsEdit = '/merchant/products/edit';
  
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
    return const CustomerHomeScreen();
  }, // Fallback home
  AppRoutes.customer: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Customer Home (${AppRoutes.customer})');
    return const CustomerHomeScreen();
  },
  AppRoutes.merchant: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Home (${AppRoutes.merchant})');
    return const MerchantHomeScreen();
  }, 
  AppRoutes.merchantHome: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Home Alternative Route (${AppRoutes.merchantHome})');
    return const MerchantHomeScreen();
  },
  
  // Merchant Routes
  AppRoutes.merchantProducts: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Merchant Products (${AppRoutes.merchantProducts})');
    return const ProductListScreen();
  },
  AppRoutes.merchantProductsAdd: (context) {
    print('${AppRoutes._logPrefix} NAVIGATED TO: Add Product Form (${AppRoutes.merchantProductsAdd})');
    return const ProductFormScreen();
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