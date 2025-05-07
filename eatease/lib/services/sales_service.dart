import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/order_model.dart';

class SalesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection references
  CollectionReference get _orders => _firestore.collection('orders');
  CollectionReference get _sales => _firestore.collection('sales');
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Get orders for the current merchant
  Stream<List<OrderModel>> getMerchantOrders() {
    if (currentUserId == null) {
      return Stream.value([]);
    }
    
    return _orders
      .where('merchantId', isEqualTo: currentUserId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
  }
  
  // Get sales summary for the current merchant (by day for the last 7 days)
  Future<List<Map<String, dynamic>>> getMerchantSalesSummaryByDay() async {
    if (currentUserId == null) {
      return [];
    }
    
    try {
      // Calculate dates for the last 7 days
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      // Query completed orders from the last 7 days
      final snapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: sevenDaysAgo)
        .get();
      
      // Process the data to group by day
      Map<String, double> dailySales = {};
      Map<String, int> dailyOrders = {};
      
      // Initialize the map with the last 7 days
      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySales[dateString] = 0;
        dailyOrders[dateString] = 0;
      }
      
      // Sum up sales for each day
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final completedAt = (data['completedAt'] as Timestamp).toDate();
        final dateString = '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}-${completedAt.day.toString().padLeft(2, '0')}';
        final amount = (data['totalAmount'] as num).toDouble();
        
        dailySales[dateString] = (dailySales[dateString] ?? 0) + amount;
        dailyOrders[dateString] = (dailyOrders[dateString] ?? 0) + 1;
      }
      
      // Convert to list format for the chart
      List<Map<String, dynamic>> result = [];
      dailySales.forEach((date, amount) {
        result.add({
          'date': date,
          'amount': amount,
          'count': dailyOrders[date] ?? 0,
        });
      });
      
      // Sort by date
      result.sort((a, b) => a['date'].compareTo(b['date']));
      
      return result;
    } catch (e) {
      print('Error getting sales summary: $e');
      return [];
    }
  }
  
  // Get total sales for the current merchant
  Future<Map<String, dynamic>> getMerchantSalesStats() async {
    if (currentUserId == null) {
      return {
        'totalSales': 0.0,
        'totalOrders': 0,
        'averageOrder': 0.0,
        'todaySales': 0.0,
        'todayOrders': 0,
      };
    }
    
    try {
      // Get all completed orders
      final allOrdersSnapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'completed')
        .get();
      
      // Calculate total sales and orders
      double totalSales = 0;
      int totalOrders = allOrdersSnapshot.docs.length;
      
      for (var doc in allOrdersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        totalSales += (data['totalAmount'] as num).toDouble();
      }
      
      // Calculate average order value
      double averageOrder = totalOrders > 0 ? totalSales / totalOrders : 0;
      
      // Get today's orders
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      final todayOrdersSnapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: startOfDay)
        .get();
      
      // Calculate today's sales and orders
      double todaySales = 0;
      int todayOrders = todayOrdersSnapshot.docs.length;
      
      for (var doc in todayOrdersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        todaySales += (data['totalAmount'] as num).toDouble();
      }
      
      return {
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'averageOrder': averageOrder,
        'todaySales': todaySales,
        'todayOrders': todayOrders,
      };
    } catch (e) {
      print('Error getting sales stats: $e');
      return {
        'totalSales': 0.0,
        'totalOrders': 0,
        'averageOrder': 0.0,
        'todaySales': 0.0,
        'todayOrders': 0,
      };
    }
  }
  
  // Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 5}) async {
    if (currentUserId == null) {
      return [];
    }
    
    try {
      // Get all completed orders
      final ordersSnapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'completed')
        .get();
      
      // Count occurrences of each product
      Map<String, int> productCounts = {};
      Map<String, String> productNames = {};
      Map<String, double> productRevenue = {};
      
      // Process each order
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        
        for (var item in items) {
          final productId = item['productId'] as String;
          final quantity = (item['quantity'] as num).toInt();
          final price = (item['price'] as num).toDouble();
          
          productCounts[productId] = (productCounts[productId] ?? 0) + quantity;
          productNames[productId] = item['name'] as String;
          productRevenue[productId] = (productRevenue[productId] ?? 0) + (price * quantity);
        }
      }
      
      // Convert to list and sort by count
      List<Map<String, dynamic>> result = [];
      productCounts.forEach((productId, count) {
        result.add({
          'productId': productId,
          'name': productNames[productId] ?? 'Unknown Product',
          'count': count,
          'revenue': productRevenue[productId] ?? 0.0,
        });
      });
      
      // Sort by count in descending order
      result.sort((a, b) => b['count'].compareTo(a['count']));
      
      // Limit the result
      if (result.length > limit) {
        result = result.sublist(0, limit);
      }
      
      return result;
    } catch (e) {
      print('Error getting top selling products: $e');
      return [];
    }
  }
  
  // Get latest transactions for the current merchant
  Future<List<OrderModel>> getLatestTransactions({int limit = 5}) async {
    if (currentUserId == null) {
      return [];
    }
    
    try {
      final snapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
      
      return snapshot.docs.map((doc) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting latest transactions: $e');
      return [];
    }
  }
} 