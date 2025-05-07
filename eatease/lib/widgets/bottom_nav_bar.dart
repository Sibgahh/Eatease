import 'package:flutter/material.dart';
import '../routes.dart';
import '../services/auth/auth_service.dart';
import '../screens/customer/cart_screen.dart';
import '../screens/customer/profile_screen.dart';
import '../screens/customer/customer_home_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userRole;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.userRole,
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Orders coming soon!'),
                    backgroundColor: Colors.green.shade600,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                break;
              case 3:
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
            _buildBottomNavItem(Icons.person_outline, Icons.person, 'Profile', 3),
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
            
            switch (index) {
              case 0:
                Navigator.pushReplacementNamed(context, AppRoutes.merchant);
                break;
              case 1:
                Navigator.pushReplacementNamed(context, AppRoutes.merchantProducts);
                break;
              case 2:
                // Navigate to orders
                Navigator.pushReplacementNamed(context, AppRoutes.merchantOrders);
                break;
              case 3:
                // Navigate to settings
                Navigator.pushReplacementNamed(context, AppRoutes.merchantSettings);
                break;
            }
          },
          items: [
            _buildBottomNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
            _buildBottomNavItem(Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Products', 1),
            _buildBottomNavItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', 2),
            _buildBottomNavItem(Icons.settings_outlined, Icons.settings, 'Settings', 3),
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
              case 2:
                // View as customer
                Navigator.pushReplacementNamed(context, AppRoutes.customer);
                break;
              case 3:
                // View as merchant
                Navigator.pushReplacementNamed(context, AppRoutes.merchant);
                break;
            }
          },
          items: [
            _buildBottomNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 0),
            _buildBottomNavItem(Icons.people_outline, Icons.people, 'Users', 1),
            _buildBottomNavItem(Icons.person_outline, Icons.person, 'Customer View', 2),
            _buildBottomNavItem(Icons.store_outlined, Icons.store, 'Merchant View', 3),
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