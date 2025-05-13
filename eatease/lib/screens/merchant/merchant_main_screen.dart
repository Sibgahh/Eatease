import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'merchant_home_screen.dart';
import 'product_list_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_settings_screen.dart';
import '../../routes.dart';
import '../../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'merchant_chat_screen.dart';

// Main container screen for merchant tabs
class MerchantMainScreen extends StatefulWidget {
  final int initialTab;
  
  const MerchantMainScreen({
    Key? key,
    this.initialTab = 0,
  }) : super(key: key);

  @override
  State<MerchantMainScreen> createState() => _MerchantMainScreenState();
}

class _MerchantMainScreenState extends State<MerchantMainScreen> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  final AuthService _authService = AuthService();
  TabController? _ordersTabController;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    
    // Initialize the tab controller if needed
    if (_currentIndex == 2) {
      _ordersTabController = TabController(length: 3, vsync: this);
    }
    
    // Add a post-frame callback to ensure the tab controller is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentIndex == 2 && _ordersTabController == null) {
        setState(() {
          _ordersTabController = TabController(length: 3, vsync: this);
        });
      }
    });
  }
  
  @override
  void dispose() {
    _ordersTabController?.dispose();
    super.dispose();
  }

  // Method to handle changing tabs
  void _changeTab(int index) {
    setState(() {
      // Convert bottom nav index to internal index
      _currentIndex = _mapNewToOldIndex(index);
      
      // Initialize the orders tab controller if needed
      if (_currentIndex == 2 && _ordersTabController == null) {
        _ordersTabController = TabController(length: 3, vsync: this);
      }
    });
  }
  
  // Get the appropriate AppBar for the current tab
  PreferredSizeWidget _getAppBar() {
    switch (_currentIndex) {
      case 0: // Home tab
        return AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textPrimaryColor,
          centerTitle: false,
          title: Row(
            children: [
              Image.asset(
                'assets/images/logo.png', 
                height: 32,
                errorBuilder: (ctx, obj, st) => Icon(
                  Icons.restaurant, 
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'EatEase Merchant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          actions: [
            // Admin Panel Button (only visible to admins)
            FutureBuilder<bool>(
              future: _authService.isAdmin(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                  return const SizedBox();
                }
                
                return IconButton(
                  icon: Icon(
                    Icons.admin_panel_settings,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin');
                  },
                  tooltip: 'Admin Dashboard',
                );
              },
            ),
          ],
        );
      case 1: // Products tab
        return AppBar(
          title: const Text(
            'My Products',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, size: 26),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.merchantProductsAdd);
              },
            ),
          ],
        );
      case 2: // Orders tab
        return AppBar(
          title: const Text('Orders'),
          backgroundColor: AppTheme.primaryColor,
          bottom: TabBar(
            controller: _ordersTabController,
            tabs: const [
              Tab(text: 'New Orders'),
              Tab(text: 'In Progress'),
              Tab(text: 'Completed'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        );
      case 3: // Chat tab
        return AppBar(
          title: const Text(
            'Customer Messages',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh by rebuilding the screen
                if (mounted) {
                  setState(() {
                    // Trigger rebuild
                  });
                }
              },
              tooltip: 'Refresh',
            ),
          ],
        );
      case 4: // Settings tab
        return AppBar(
          title: const Text(
            'Settings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.primaryColor,
        );
      default:
        return AppBar(
          title: const Text('Merchant'),
          backgroundColor: AppTheme.primaryColor,
        );
    }
  }
  
  // Get the body content for the current tab
  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return const MerchantHomeScreen(showScaffold: false);
      case 1:
        return const ProductListScreen(showScaffold: false);
      case 2:
        if (_ordersTabController != null) {
          return TabBarView(
            controller: _ordersTabController,
            children: const [
              MerchantOrdersList(status: 'pending'),
              MerchantOrdersList(status: 'preparing'),
              MerchantOrdersList(status: 'completed'),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      case 3:
        // Chat screen
        return const MerchantChatScreen(showScaffold: false);
      case 4:
        // Settings screen
        return const MerchantSettingsScreen(showScaffold: false);
      default:
        return const Center(child: Text('Unknown tab'));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // If we're switching to the Orders tab, initialize the tab controller
    if (_currentIndex == 2 && _ordersTabController == null) {
      _ordersTabController = TabController(length: 3, vsync: this);
    }
    
    // Use the index mapping for consistent navigation
    int navBarIndex = _mapOldIndexToNew(_currentIndex);
    
    return Scaffold(
      appBar: _getAppBar(),
      body: _getBody(),
      bottomNavigationBar: Container(
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
          children: [
            _buildNavItem(icon: Icons.home_rounded, index: 0, isSelected: navBarIndex == 0),
            _buildNavItem(icon: Icons.restaurant_menu_rounded, index: 1, isSelected: navBarIndex == 1),
            _buildNavItem(icon: Icons.receipt_long_rounded, index: 2, isSelected: navBarIndex == 2),
            _buildNavItem(icon: Icons.chat_rounded, index: 3, isSelected: navBarIndex == 3),
            _buildNavItem(icon: Icons.settings_rounded, index: 4, isSelected: navBarIndex == 4),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavItem({required IconData icon, required int index, required bool isSelected}) {
    final Color primaryColor = AppTheme.getPrimaryColor('merchant');
    
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isSelected) {
              _changeTab(index);
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

  // Map old indices to new ones (for bottom nav)
  int _mapOldIndexToNew(int oldIndex) {
    switch (oldIndex) {
      case 0: // Home -> Home (index 0) 
        return 0;
      case 1: // Products -> Products (index 1)
        return 1; 
      case 2: // Orders -> Orders (index 2)
        return 2;
      case 3: // Chat -> Chat (index 3)
        return 3;
      case 4: // Settings -> Settings (index 4)
        return 4;
      default:
        return 0; // Default to Home
    }
  }
  
  // Map new indices to old ones (for changing tabs)
  int _mapNewToOldIndex(int navIndex) {
    switch (navIndex) {
      case 0: // Home navigation -> Home content (0)
        return 0;
      case 1: // Products navigation -> Products content (1)
        return 1;
      case 2: // Orders navigation -> Orders content (2)
        return 2;
      case 3: // Chat navigation -> Chat content (3)
        return 3;
      case 4: // Settings navigation -> Settings content (4)
        return 4;
      default:
        return 0;
    }
  }
}

// Content classes for each tab (without Scaffold)
class MerchantHomeContent extends StatefulWidget {
  const MerchantHomeContent({Key? key}) : super(key: key);

  @override
  State<MerchantHomeContent> createState() => _MerchantHomeContentState();
}

class _MerchantHomeContentState extends State<MerchantHomeContent> {
  @override
  Widget build(BuildContext context) {
    // Get the actual MerchantHomeScreen's body content
    return const MerchantHomeScreen();
  }
}

class ProductListContent extends StatelessWidget {
  const ProductListContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the actual ProductListScreen's body content
    return const ProductListScreen();
  }
}

class MerchantOrdersContent extends StatelessWidget {
  final TabController tabController;
  
  const MerchantOrdersContent({
    Key? key,
    required this.tabController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Create a tab view that uses the shared tab controller
    return TabBarView(
      controller: tabController,
      children: const [
        MerchantOrdersList(status: 'pending'),
        MerchantOrdersList(status: 'preparing'),
        MerchantOrdersList(status: 'completed'),
      ],
    );
  }
}

// Temporary class for MerchantOrdersList until the real one is properly imported
class MerchantOrdersList extends StatefulWidget {
  final String status;
  
  const MerchantOrdersList({
    Key? key,
    required this.status,
  }) : super(key: key);

  @override
  State<MerchantOrdersList> createState() => _MerchantOrdersListState();
}

class _MerchantOrdersListState extends State<MerchantOrdersList> {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  String? _merchantId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadMerchantId();
  }
  
  Future<void> _loadMerchantId() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        setState(() {
          _merchantId = user.uid;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading merchant ID: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_merchantId == null) {
      return const Center(
        child: Text('Unable to load merchant information'),
      );
    }

    // Map the order status for query
    List<String> statusList = [];
    switch (widget.status) {
      case 'pending':
        statusList = ['pending'];
        break;
      case 'preparing':
        statusList = ['preparing', 'ready'];
        break;
      case 'completed':
        statusList = ['completed'];
        break;
    }

    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.getMerchantOrdersByStatus(_merchantId!, statusList),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No ${widget.status == 'pending' ? 'new' : widget.status} orders',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildOrderCard(order);
          },
        );
      },
    );
  }
  
  Widget _buildOrderCard(OrderModel order) {
    String statusText = '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;

    switch (order.status) {
      case 'pending':
        statusText = 'New Order';
        statusColor = Colors.orange;
        statusIcon = Icons.notifications_active;
        break;
      case 'preparing':
        statusText = 'Preparing';
        statusColor = Colors.blue;
        statusIcon = Icons.restaurant;
        break;
      case 'ready':
        statusText = 'Ready';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        statusText = 'Completed';
        statusColor = Colors.green.shade800;
        statusIcon = Icons.task_alt;
        break;
      case 'cancelled':
        statusText = 'Cancelled';
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {}, // Handle order details
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, math.min(8, order.id.length))}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: statusColor,
                    avatar: Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Customer: ${order.customerName}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Order Time: ${_formatDateTime(order.createdAt)}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${order.items.length} items',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Rp ${order.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              if (order.status == 'pending')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _updateOrderStatus(order, 'preparing'),
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _updateOrderStatus(order, 'cancelled'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              if (order.status == 'preparing')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'ready'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Ready'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
              if (order.status == 'ready')
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(order, 'completed'),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _updateOrderStatus(OrderModel order, String newStatus) {
    try {
      FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update({
            'status': newStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            if (newStatus == 'completed') 'completedAt': FieldValue.serverTimestamp(),
          });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _formatDateTime(DateTime dateTime) {
    // Format time as: Today, 3:45 PM or 12 July, 3:45 PM
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour == 0 ? 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    
    if (date == today) {
      return 'Today, $hour:$minute $period';
    } else {
      final List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${dateTime.day} ${months[dateTime.month - 1]}, $hour:$minute $period';
    }
  }
}

class MerchantSettingsContent extends StatelessWidget {
  const MerchantSettingsContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the actual MerchantSettingsScreen's body content
    return const MerchantSettingsScreen();
  }
} 