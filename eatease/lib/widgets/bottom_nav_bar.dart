import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../utils/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String userRole;
  final Function(int)? onTabChange;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.userRole,
    this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    // Get role-specific colors
    final primaryColor = AppTheme.getPrimaryColor(userRole);
    
    // Define tab items based on user role
    final List<Map<String, dynamic>> navItems = _getNavItemsForRole(userRole);
    
    return Container(
      height: 60,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(navItems.length, (index) {
          bool isSelected = currentIndex == index;
          
          return _buildNavItem(
            context: context,
            icon: navItems[index]['icon'],
            index: index,
            isSelected: isSelected,
            primaryColor: primaryColor,
          );
        }),
      ),
    );
  }

  List<Map<String, dynamic>> _getNavItemsForRole(String role) {
    switch (role.toLowerCase()) {
      case 'customer':
        return [
          {'icon': Icons.home_rounded},
          {'icon': Icons.shopping_cart_rounded},
          {'icon': Icons.receipt_long_rounded},
          {'icon': Icons.chat_rounded},
          {'icon': Icons.person_rounded},
        ];
      case 'merchant':
        return [
          {'icon': Icons.home_rounded},
          {'icon': Icons.restaurant_menu_rounded},
          {'icon': Icons.receipt_long_rounded},
          {'icon': Icons.chat_rounded},
          {'icon': Icons.settings_rounded},
        ];
      case 'admin':
        return [
          {'icon': Icons.dashboard_rounded},
          {'icon': Icons.people_rounded},
          {'icon': Icons.home_rounded},
          {'icon': Icons.analytics_rounded},
          {'icon': Icons.settings_rounded},
        ];
      default:
        return [
          {'icon': Icons.home_rounded},
          {'icon': Icons.shopping_cart_rounded},
          {'icon': Icons.receipt_long_rounded},
          {'icon': Icons.chat_rounded},
          {'icon': Icons.person_rounded},
        ];
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required int index,
    required bool isSelected,
    required Color primaryColor,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              HapticFeedback.lightImpact();
              _navigateToPage(index, context);
            }
          },
          customBorder: const StadiumBorder(),
          splashColor: primaryColor.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  height: isSelected ? 3 : 0,
                  width: 20,
                  margin: isSelected ? const EdgeInsets.only(bottom: 4) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Icon(
                  icon,
                  color: isSelected ? primaryColor : Colors.grey.shade400,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToPage(int index, BuildContext context) {
    if (currentIndex == index) return;

    // If an onTabChange callback is provided, use it instead of navigation
    if (onTabChange != null) {
      onTabChange!(index);
      return;
    }

    if (userRole == 'customer') {
      _navigateCustomerPage(index, context);
    } else if (userRole == 'merchant') {
      _navigateMerchantPage(index, context);
    } else if (userRole == 'admin') {
      _navigateAdminPage(index, context);
    }
  }

  void _navigateCustomerPage(int index, BuildContext context) {
    switch (index) {
      case 0: // Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerHomeScreen(),
          ),
          (route) => false,
        );
        break;
      case 1: // Cart
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CartScreen(),
          ),
        );
        break;
      case 2: // Orders
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerOrdersScreen(),
          ),
        );
        break;
      case 3: // Chat
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerChatScreen(),
          ),
        );
        break;
      case 4: // Profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CustomerProfileScreen(),
          ),
        );
        break;
    }
  }

  void _navigateMerchantPage(int index, BuildContext context) {
    switch (index) {
      case 0: // Home
        Navigator.pushNamedAndRemoveUntil(
          context, 
          AppRoutes.merchant,
          (route) => false,
        );
        break;
      case 1: // Products
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.merchantProducts,
          (route) => false,
        );
        break;
      case 2: // Orders
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.merchantOrders,
          (route) => false,
        );
        break;
      case 3: // Chat
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.merchantChat,
          (route) => false,
        );
        break;
      case 4: // Settings
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.merchantSettings,
          (route) => false,
        );
        break;
    }
  }

  void _navigateAdminPage(int index, BuildContext context) {
    switch (index) {
      case 0: // Dashboard
        // Handle dashboard navigation
        break;
      case 1: // Users
        // Handle users navigation
        break;
      case 2: // Home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MerchantHomeScreen(),
            settings: const RouteSettings(name: '/admin'),
          ),
          (route) => false,
        );
        break;
      case 3: // Analytics
        // Handle analytics navigation
        break;
      case 4: // Settings
        // Handle settings navigation
        break;
    }
  }
} 