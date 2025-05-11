import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/auth/auth_service.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/customer_home_screen.dart';
import '../screens/customer/customer_orders_screen.dart';
import '../screens/customer/chat/customer_chat_screen.dart';
import '../screens/merchant/merchant_home_screen.dart';
import '../screens/merchant/product_list_screen.dart';
import '../screens/merchant/merchant_orders_screen.dart';
import '../screens/merchant/merchant_settings_screen.dart';
import '../screens/merchant/merchant_chat_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final Function(int)? onTabChanged;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.userRole,
    this.onTabChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Different navigation items based on user role
    if (userRole == 'customer') {
      return _buildCustomerBottomNav(context);
    } else if (userRole == 'merchant') {
      return _buildMerchantBottomNav(context);
    } else if (userRole == 'admin') {
      return _buildAdminBottomNav(context);
    }
    
    // Default to customer bottom nav if role is unknown
    return _buildCustomerBottomNav(context);
  }

  // Helper method to navigate between main tabs
  void _navigateToMainTab(BuildContext context, String routeName) {
    // Get the current route name
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    // If we're already on this route, do nothing
    if (currentRoute == routeName) return;
    
    // Check if we're on one of the main tabs
    final isOnMainTab = [
      AppRoutes.customer,
      AppRoutes.customerProfile,
      // Add other main customer routes here if needed
    ].contains(currentRoute);
    
    if (isOnMainTab) {
      // If we're on a main tab, use pushReplacementNamed to avoid stacking
      Navigator.pushReplacementNamed(context, routeName);
    } else {
      // If we're on a sub-screen, clear everything back to the main tab
      Navigator.pushNamedAndRemoveUntil(
        context, 
        routeName,
        (route) => false,
      );
    }
  }

  Widget _buildCustomerBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.green.shade600,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          elevation: 0,
          onTap: (index) {
            if (index == currentIndex) return;
            
            switch (index) {
              case 0:
                // Direct navigation to home screen
                print('[NAVIGATION] Directly navigating to Home using MaterialPageRoute');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerHomeScreen(),
                    settings: const RouteSettings(name: AppRoutes.customer),
                  ),
                  (route) => false, // Clear all other routes
                );
                break;
              case 1:
                // Navigate to cart
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartScreen()),
                );
                break;
              case 2:
                // Navigate to orders
                print('[NAVIGATION] Directly navigating to Orders using MaterialPageRoute');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerOrdersScreen(),
                    settings: const RouteSettings(name: AppRoutes.customerOrders),
                  ),
                  (route) => false, // Clear all other routes
                );
                break;
              case 3:
                // Navigate to chat
                print('[NAVIGATION] Directly navigating to Chat using MaterialPageRoute');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerChatScreen(),
                    settings: const RouteSettings(name: AppRoutes.customerChat),
                  ),
                  (route) => false, // Clear all other routes
                );
                break;
              case 4:
                // Direct navigation to profile screen
                print('[NAVIGATION] Directly navigating to Profile using MaterialPageRoute');
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerProfileScreen(),
                    settings: const RouteSettings(name: AppRoutes.customerProfile),
                  ),
                  (route) => false, // Clear all other routes
                );
                break;
            }
          },
          items: [
            _buildBottomNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildBottomNavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Cart', 1),
            _buildBottomNavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', 2),
            _buildBottomNavItem(Icons.chat_outlined, Icons.chat, 'Chat', 3),
            _buildBottomNavItem(Icons.person_outline, Icons.person, 'Profile', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue.shade600,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          elevation: 0,
          onTap: (index) {
            if (index == currentIndex) return;
            
            // If we have an onTabChanged callback, use it
            if (onTabChanged != null) {
              onTabChanged!(index);
              return;
            }
            
            // Fallback to old navigation for backward compatibility
            switch (index) {
              case 0:
                print('[NAVIGATION] Navigating to Merchant Home');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MerchantHomeScreen(),
                  ),
                  (route) => false,
                );
                break;
              case 1:
                print('[NAVIGATION] Navigating to Merchant Products');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const ProductListScreen(),
                  ),
                  (route) => false,
                );
                break;
              case 2:
                print('[NAVIGATION] Navigating to Merchant Orders');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MerchantOrdersScreen(),
                  ),
                  (route) => false,
                );
                break;
              case 3:
                print('[NAVIGATION] Navigating to Merchant Chat');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MerchantChatScreen(),
                  ),
                  (route) => false,
                );
                break;
              case 4:
                print('[NAVIGATION] Navigating to Merchant Settings');
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const MerchantSettingsScreen(),
                  ),
                  (route) => false,
                );
                break;
            }
          },
          items: [
            _buildBottomNavItem(Icons.home_outlined, Icons.home, 'Home', 0),
            _buildBottomNavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Products', 1),
            _buildBottomNavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', 2),
            _buildBottomNavItem(Icons.chat_outlined, Icons.chat, 'Chat', 3),
            _buildBottomNavItem(Icons.settings_outlined, Icons.settings, 'Settings', 4),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.red.shade600,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
          elevation: 0,
          onTap: (index) {
            if (index == currentIndex) return;
            
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, AppRoutes.admin);
                break;
              case 1:
                Navigator.pushReplacementNamed(context, AppRoutes.adminUsers);
                break;
            }
          },
          items: [
            _buildBottomNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
            _buildBottomNavItem(Icons.people_outline, Icons.people, 'Users', 1),
          ],
        ),
      ),
    );
  }
  
  BottomNavigationBarItem _buildBottomNavItem(IconData iconOutlined, IconData iconFilled, String label, int index) {
    return BottomNavigationBarItem(
      icon: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Icon(currentIndex == index ? iconFilled : iconOutlined, size: 24),
      ),
      label: label,
    );
  }
} 