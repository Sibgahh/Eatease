import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get merchant orders by status
  Stream<List<OrderModel>> getMerchantOrdersByStatus(String merchantId, List<String> statusList) {
    return _firestore
        .collection('orders')
        .where('merchantId', isEqualTo: merchantId)
        .where('status', whereIn: statusList)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return OrderModel.fromMap(doc.data(), doc.id);
          }).toList();
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
  Future<String?> createOrder(OrderModel order) async {
    try {
      final docRef = await _firestore.collection('orders').add(order.toMap());
      return docRef.id;
    } catch (e) {
      print('Error creating order: $e');
      return null;
    }
  }
} 