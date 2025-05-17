import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/order_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'package:intl/number_symbols_data.dart';

// Separate widget for just the orders list
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
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        _merchantId = user.uid;
      }
    } catch (e) {
      print('Error loading merchant ID: $e');
    } finally {
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
            return MerchantOrdersScreen.buildOrderCard(context, order);
          },
        );
      },
    );
  }
}

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({Key? key}) : super(key: key);

  // Static method to build an order card that can be used anywhere
  static Widget buildOrderCard(BuildContext context, OrderModel order) {
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
        onTap: () => _showOrderDetails(context, order),
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
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusText,
                      style: TextStyle(
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
                    '\$${order.totalAmount.toStringAsFixed(2)}',
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
                        onPressed: () => _updateOrderStatus(context, order, 'preparing'),
                        icon: const Icon(Icons.check),
                        label: const Text('Accept'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _updateOrderStatus(context, order, 'cancelled'),
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
                    onPressed: () => _updateOrderStatus(context, order, 'ready'),
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
                    onPressed: () => _updateOrderStatus(context, order, 'completed'),
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
  
  // Extracted static helper methods
  static String _formatDateTime(DateTime dateTime) {
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

  static void _showOrderDetails(BuildContext context, OrderModel order) {
    final MerchantOrdersScreenState? state = context.findAncestorStateOfType<MerchantOrdersScreenState>();
    if (state != null) {
      state._showOrderDetails(order);
    }
  }
  
  static void _updateOrderStatus(BuildContext context, OrderModel order, String newStatus) {
    final MerchantOrdersScreenState? state = context.findAncestorStateOfType<MerchantOrdersScreenState>();
    if (state != null) {
      state._updateOrderStatus(order, newStatus);
    }
  }

  @override
  State<MerchantOrdersScreen> createState() => MerchantOrdersScreenState();
}

class MerchantOrdersScreenState extends State<MerchantOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  String? _merchantId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMerchantId();
  }

  Future<void> _loadMerchantId() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        _merchantId = user.uid;
      }
    } catch (e) {
      print('Error loading merchant ID: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: AppTheme.primaryColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'New Orders'),
            Tab(text: 'In Progress'),
            Tab(text: 'Completed'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildOrdersList('pending'),
          buildOrdersList('preparing'),
          buildOrdersList('completed'),
        ],
      ),
    );
  }

  Widget buildOrdersList(String orderStatus) {
    if (_merchantId == null) {
      return const Center(
        child: Text('Unable to load merchant information'),
      );
    }

    // Map the order status for query
    List<String> statusList = [];
    switch (orderStatus) {
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
                  'No ${orderStatus == 'pending' ? 'new' : orderStatus} orders',
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
        onTap: () => _showOrderDetails(order),
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
                    'Order #${order.id.substring(0, 8)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Chip(
                    label: Text(
                      statusText,
                      style: TextStyle(
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
                    '\$${order.totalAmount.toStringAsFixed(2)}',
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

  Widget _buildStatusBadge(String status) {
    return Chip(
      label: Text(
        status.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: _getStatusColor(status),
      avatar: Icon(
        _getStatusIcon(status),
        color: Colors.white,
        size: 16,
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollController,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  
                  // Order ID and Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 6)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Info Card
                  Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Customer Information',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.customerName,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Delivery Address',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      order.deliveryAddress,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Order timeline
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Created: ${dateFormat.format(order.createdAt)}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  
                  if (order.updatedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.update, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Last updated: ${dateFormat.format(order.updatedAt)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Order items
                  Text(
                    'Order Items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...order.items.map((item) => _buildOrderItemRow(item)),
                  const SizedBox(height: 16),
                  const Divider(),
                  
                  // Payment info
                  Text(
                    'Payment',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Status:'),
                      Text(
                        order.paymentStatus.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: order.paymentStatus == 'paid'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Payment Method:'),
                      Text(
                        order.paymentMethod,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:'),
                      Text(
                        'Rp ${NumberFormat("#,###").format(order.totalAmount.toInt())}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Customer Note
                  if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Customer Note',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.customerNote!,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  if (order.status == 'pending')
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _updateOrderStatus(order, 'preparing');
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Accept Order'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _updateOrderStatus(order, 'cancelled');
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.cancel),
                            label: const Text('Decline Order'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (order.status == 'preparing')
                    ElevatedButton.icon(
                      onPressed: () {
                        _updateOrderStatus(order, 'ready');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Ready'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  if (order.status == 'ready')
                    ElevatedButton.icon(
                      onPressed: () {
                        _updateOrderStatus(order, 'completed');
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderItemRow(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Item image or placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade200,
            ),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.fastfood,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.fastfood,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 12),
          
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.options != null && item.options!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.options!.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ]
              ],
            ),
          ),
          
          // Quantity and price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity}x',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Rp ${NumberFormat("#,###").format(item.price.toInt())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.notifications_active;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.check_circle;
      case 'completed':
        return Icons.task_alt;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'completed':
        return Colors.green.shade800;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateOrderStatus(OrderModel order, String newStatus) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    
    try {
      // SIMPLIFIED DIRECT UPDATE FOR DEBUGGING
      // This directly updates the order document in Firestore
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add completedAt timestamp if completing the order
      if (newStatus == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id)
          .update(updateData);
      
      // Ensure chat is deleted when order is completed or cancelled
      if (newStatus == 'completed' || newStatus == 'cancelled') {
        // Use the chat service to delete the order conversation
        final chatService = ChatService();
        await chatService.deleteOrderConversation(order.id);
      }
      
      // Close the loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Force UI refresh
      setState(() {});
    } catch (e) {
      // Close the loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // Show error message with details for debugging
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      print('Error updating order status: $e');
    }
  }
} 