import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../utils/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat/chat_detail_screen.dart';

class CustomerOrdersScreen extends StatefulWidget {
  final bool showScaffold;
  
  const CustomerOrdersScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  final ChatService _chatService = ChatService();
  
  // Tab controller for different order statuses
  late TabController _tabController;
  
  final List<String> _tabTitles = [
    'Active',    // pending, preparing, ready
    'Completed', // completed
    'Cancelled', // cancelled
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Get all customer orders and filter by status
  Stream<List<OrderModel>> _getCustomerOrdersByStatus(List<String> statusList) {
    // Use the getUserOrders method from OrderService that doesn't use complex queries
    return _orderService.getUserOrders().map(
      (allOrders) => allOrders.where(
        (order) => statusList.contains(order.status.toLowerCase())
      ).toList()
    );
  }
  
  // Open chat with merchant for an active order
  Future<void> _openOrderChat(OrderModel order) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to chat'))
        );
        return;
      }
      
      final conversationId = await _chatService.createOrGetOrderConversation(
        user.uid,
        order.merchantId,
        order.id
      );
      
      if (!mounted) return;
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            conversationId: conversationId,
            otherUserId: order.merchantId,
            otherUserName: order.merchantName,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening chat: $e'))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = TabBarView(
      controller: _tabController,
      children: [
        // Active Orders Tab (pending, preparing, ready)
        _buildOrdersTab(['pending', 'preparing', 'ready']),
        
        // Completed Orders Tab
        _buildOrdersTab(['completed']),
        
        // Cancelled Orders Tab
        _buildOrdersTab(['cancelled']),
      ],
    );
    
    if (!widget.showScaffold) {
      return content;
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
        ),
      ),
      body: content,
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'customer';
          return BottomNavBar(
            currentIndex: 2, // Orders tab remains at index 2
            userRole: userRole,
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab(List<String> statusList) {
    return StreamBuilder<List<OrderModel>>(
      stream: _getCustomerOrdersByStatus(statusList),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }
        
        final orders = snapshot.data ?? [];
        
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getEmptyStateIcon(statusList.first),
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEmptyStateMessage(statusList.first),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        // Sort orders by creation date (newest first)
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            // Pass the status list to determine if this is an active order
            return _buildOrderCard(order, statusList);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, List<String> statusList) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final formattedDate = dateFormat.format(order.createdAt);
    final bool isActiveOrder = statusList.contains('pending') || statusList.contains('preparing') || statusList.contains('ready');
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _showOrderDetails(order);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order ID and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order.id.substring(0, 6)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Divider(),
              
              // Merchant Name
              Row(
                children: [
                  const Icon(Icons.store, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.merchantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Order items summary
              Text(
                '${order.items.length} item(s): ${order.items.map((e) => e.name).take(2).join(", ")}${order.items.length > 2 ? "..." : ""}',
                style: const TextStyle(
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Status and amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusBadge(order.status),
                  Text(
                    'Rp ${NumberFormat("#,###").format(order.totalAmount.toInt())}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              
              // Chat button for active orders only
              if (isActiveOrder) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openOrderChat(order),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat with Merchant'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;
    
    switch(status.toLowerCase()) {
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case 'preparing':
        color = Colors.blue;
        text = 'Preparing';
        icon = Icons.restaurant;
        break;
      case 'ready':
        color = Colors.green;
        text = 'Ready for Pickup';
        icon = Icons.check_circle;
        break;
      case 'completed':
        color = Colors.green.shade800;
        text = 'Completed';
        icon = Icons.done_all;
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'Cancelled';
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final bool isActiveOrder = ['pending', 'preparing', 'ready'].contains(order.status.toLowerCase());
    final bool isCompletedOrder = order.status.toLowerCase() == 'completed';
    
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
                  
                  // Chat button for active orders
                  if (isActiveOrder) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close the order details
                        _openOrderChat(order);
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Chat with Merchant'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(color: AppTheme.primaryColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Rating section for completed orders
                  if (isCompletedOrder) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Rate Your Order',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (order.rating != null) ...[
                      // Show existing rating
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < order.rating!.floor()
                                  ? Icons.star
                                  : (index < order.rating!.ceil() && index >= order.rating!.floor())
                                      ? Icons.star_half
                                      : Icons.star_border,
                              color: Colors.amber,
                              size: 24,
                            );
                          }),
                          const SizedBox(width: 8),
                          Text(
                            order.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (order.review != null && order.review!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            order.review!,
                            style: const TextStyle(
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ] else ...[
                      // Show rating input
                      Builder(
                        builder: (context) {
                          double rating = 0;
                          final reviewController = TextEditingController();
                          
                          return StatefulBuilder(
                            builder: (context, setState) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(5, (index) {
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            rating = index + 1.0;
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4),
                                          child: Icon(
                                            index < rating ? Icons.star : Icons.star_border,
                                            color: Colors.amber,
                                            size: 32,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: reviewController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Write your review (optional)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: rating > 0
                                          ? () async {
                                              try {
                                                await _orderService.updateOrderRating(
                                                  order.id,
                                                  rating,
                                                  reviewController.text.trim(),
                                                );
                                                if (!mounted) return;
                                                Navigator.pop(context);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Thank you for your rating!'),
                                                  ),
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Error submitting rating: $e'),
                                                  ),
                                                );
                                              }
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Submit Rating'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                  
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
                          'Last updated: ${dateFormat.format(order.updatedAt!)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                  
                  if (order.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.done_all, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Completed: ${dateFormat.format(order.completedAt!)}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // Merchant info
                  Text(
                    'Merchant',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        order.merchantName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
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
                  
                  // Order notes
                  if (order.customerNote != null && order.customerNote!.isNotEmpty) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      'Your Note',
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
                  
                  if (order.merchantNote != null && order.merchantNote!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Merchant Note',
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
                        order.merchantNote!,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons based on order status
                  if (order.status == 'pending') ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                      ),
                      onPressed: () => _cancelOrder(order.id),
                      child: const Text('Cancel Order'),
                    ),
                  ],
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

  Future<void> _cancelOrder(String orderId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      try {
        Navigator.pop(context); // Close the order details
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cancelling order...')),
        );
        
        await _orderService.updateOrderStatusInDB(orderId, 'cancelled');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  IconData _getEmptyStateIcon(String status) {
    switch (status) {
      case 'pending':
      case 'preparing':
      case 'ready':
        return Icons.receipt_long;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.receipt;
    }
  }

  String _getEmptyStateMessage(String status) {
    switch (status) {
      case 'pending':
      case 'preparing':
      case 'ready':
        return 'You don\'t have any active orders.\nOrder some delicious food!';
      case 'completed':
        return 'You don\'t have any completed orders yet';
      case 'cancelled':
        return 'You don\'t have any cancelled orders';
      default:
        return 'No orders found';
    }
  }
} 