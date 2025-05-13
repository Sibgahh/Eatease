import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/order_model.dart';
import '../services/auth/auth_service.dart';
import '../services/cart_service.dart';
import '../services/chat_service.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final AuthService _authService = AuthService();
  final CartService _cartService = CartService();
  final ChatService _chatService = ChatService();

  // Get merchant orders by status
  Stream<List<OrderModel>> getMerchantOrdersByStatus(String merchantId, List<String> statusList) {
    // For single status, we can use a simpler query
    if (statusList.length == 1) {
      return _firestore
          .collection('orders')
          .where('merchantId', isEqualTo: merchantId)
          .where('status', isEqualTo: statusList[0])
          .snapshots()
          .map((snapshot) {
            final orders = snapshot.docs.map((doc) {
              return OrderModel.fromMap(doc.data(), doc.id);
            }).toList();
            
            // Sort by creation date (newest first)
            orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return orders;
          });
    }
    
    // For multiple statuses, get all merchant orders and filter in memory
    return _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .where((order) => statusList.contains(order.status.toLowerCase()))
            .toList();
          
          // Sort by creation date (newest first)
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  // Update order status using Cloud Functions
  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final HttpsCallable updateOrderStatus = _functions.httpsCallable('updateOrderStatus');
      
      // Call the function with order data
      final result = await updateOrderStatus.call({
        'orderId': orderId,
        'newStatus': newStatus,
      });
      
      // If status is completed, delete any associated chat
      if (newStatus == 'completed') {
        await _chatService.deleteOrderConversation(orderId);
      }
      
      return {
        'success': result.data['success'] as bool,
        'message': result.data['message'] as String,
      };
    } on FirebaseFunctionsException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Error updating order status',
        'error': e,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: $e',
        'error': e,
      };
    }
  }

  // Get an order by ID
  Future<OrderModel?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection('orders').doc(orderId).get();
      
      if (!doc.exists) {
        return null;
      }
      
      return OrderModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      print('Error getting order: $e');
      return null;
    }
  }

  // Create a new order
  Future<String> createOrder(OrderModel order) async {
    try {
      // Create order document in Firestore
      final orderRef = await _firestore.collection('orders').add(order.toMap());
      
      // Get merchant information to update the order
      final merchantData = await _firestore.collection('users').doc(order.merchantId).get();
      final merchantName = merchantData.data()?['storeName'] ?? merchantData.data()?['displayName'] ?? 'Restaurant';
      
      // Update the order with the merchant name
      await orderRef.update({
        'merchantName': merchantName,
      });
      
      // Clear the cart after successful order
      _cartService.clearCart();
      
      return orderRef.id;
    } catch (e) {
      print('Error creating order: $e');
      throw Exception('Failed to create order: $e');
    }
  }

  // Get orders for current user
  Stream<List<OrderModel>> getUserOrders() {
    final user = _authService.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    
    // Removed the orderBy clause to avoid needing a composite index
    return _firestore
        .collection('orders')
        .where('customerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  // Get order by ID
  Stream<OrderModel?> getOrderByIdStream(String orderId) {
    return _firestore
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((snapshot) => snapshot.exists
            ? OrderModel.fromMap(snapshot.data()!, snapshot.id)
            : null);
  }
  
  // Update order status directly in DB
  Future<void> updateOrderStatusInDB(String orderId, String status) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // If status is completed, delete any associated chat
      if (status == 'completed') {
        await _chatService.deleteOrderConversation(orderId);
      }
    } catch (e) {
      print('Error updating order status: $e');
      throw Exception('Failed to update order status: $e');
    }
  }
  
  // Update payment status
  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'paymentStatus': paymentStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating payment status: $e');
      throw Exception('Failed to update payment status: $e');
    }
  }
  
  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Delete any associated chat
      await _chatService.deleteOrderConversation(orderId);
    } catch (e) {
      print('Error cancelling order: $e');
      throw Exception('Failed to cancel order: $e');
    }
  }
} 