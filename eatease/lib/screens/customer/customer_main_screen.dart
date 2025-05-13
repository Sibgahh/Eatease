import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'customer_home_screen.dart';
import 'cart_screen.dart';
import 'customer_orders_screen.dart';
import 'chat/customer_chat_screen.dart';
import 'profile_screen.dart';
import '../../routes.dart';
import '../../utils/app_theme.dart';

// Main container screen for customer tabs
class CustomerMainScreen extends StatefulWidget {
  final int initialTab;
  
  const CustomerMainScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  late int _currentIndex;
  final AuthService _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  // Method to handle changing tabs
  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
  
  // Get the appropriate AppBar for the current tab
  PreferredSizeWidget _getAppBar() {
    switch (_currentIndex) {
      case 0: // Home tab
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 0,
        );
      case 1: // Cart tab
        return AppBar(
          title: const Text(
            'My Cart',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        );
      case 2: // Orders tab
        return AppBar(
          title: const Text(
            'My Orders',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        );
      case 3: // Chat tab
        return AppBar(
          title: const Text(
            'Messages',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        );
      case 4: // Profile tab
        return AppBar(
          title: const Text(
            'My Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        );
      default:
        return AppBar(
          title: const Text('EatEase'),
          backgroundColor: AppTheme.primaryColor,
        );
    }
  }
  
  // Get the body content for the current tab
  Widget _getBody() {
    // Use IndexedStack to maintain all tabs in memory and avoid animation
    return IndexedStack(
      index: _currentIndex,
      children: const [
        CustomerHomeScreen(),
        CartScreen(showScaffold: false),
        CustomerOrdersScreen(showScaffold: false),
        CustomerChatScreen(showScaffold: false),
        CustomerProfileScreen(showScaffold: false),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _getAppBar(),
      body: _getBody(),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        userRole: 'customer',
        onTabChange: _changeTab,
      ),
    );
  }
} 