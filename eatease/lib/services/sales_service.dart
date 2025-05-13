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
  
  // Status list for paid orders - we'll now only focus on completed orders
  final List<String> _paidOrderStatuses = ['completed'];
  
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
      print('SalesService: Fetching merchant sales stats for merchantId: $currentUserId');
      
      // Use a simpler query to avoid index issues - just get all orders for this merchant
      final allOrdersSnapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .get();
      
      print('SalesService: Retrieved ${allOrdersSnapshot.docs.length} total orders from Firestore');
      
      // Calculate total sales and orders - filter in memory
      double totalSales = 0;
      int totalOrders = 0;
      
      // Get today's date at the start of the day for filtering
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      
      // Today's sales
      double todaySales = 0;
      int todayOrders = 0;
      
      for (var doc in allOrdersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        final paymentStatus = (data['paymentStatus'] as String?)?.toLowerCase() ?? '';
        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        
        // Only count completed orders with paid status
        if (status == 'completed' && paymentStatus == 'paid') {
          print('SalesService: Found completed order ${doc.id} - Amount: $amount');
          
          totalSales += amount;
          totalOrders++;
          
          // Check if it's from today
          if (createdAt != null && createdAt.isAfter(startOfDay)) {
            todaySales += amount;
            todayOrders++;
          }
        }
      }
      
      // Calculate average order value
      double averageOrder = totalOrders > 0 ? totalSales / totalOrders : 0;
      
      final result = {
        'totalSales': totalSales,
        'totalOrders': totalOrders,
        'averageOrder': averageOrder,
        'todaySales': todaySales,
        'todayOrders': todayOrders,
      };
      
      print('SalesService: Final sales stats (completed orders only): $result');
      return result;
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
  
  // Get sales summary for the current merchant (by day for the last 7 days)
  Future<List<Map<String, dynamic>>> getMerchantSalesSummaryByDay() async {
    if (currentUserId == null) {
      return [];
    }
    
    try {
      // Calculate dates for the last 7 days
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      // Use a simpler query to avoid index issues
      final snapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .get();
      
      print('SalesService: Retrieved ${snapshot.docs.length} orders for sales summary');
      
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
      
      // Sum up sales for each day, filtering for completed and paid orders
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        final paymentStatus = (data['paymentStatus'] as String?)?.toLowerCase() ?? '';
        final createdAtTimestamp = data['createdAt'] as Timestamp?;
        
        // Skip if not a completed and paid order, or if older than 7 days
        if (status != 'completed' || paymentStatus != 'paid' || createdAtTimestamp == null) {
          continue;
        }
        
        final orderDate = createdAtTimestamp.toDate();
        if (orderDate.isBefore(sevenDaysAgo)) {
          continue;
        }
        
        final dateString = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
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
  
  // Get top selling products
  Future<List<Map<String, dynamic>>> getTopSellingProducts({int limit = 5}) async {
    if (currentUserId == null) {
      return [];
    }
    
    try {
      // Use a simpler query to avoid index issues
      final ordersSnapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .get();
      
      print('SalesService: Retrieved ${ordersSnapshot.docs.length} total orders for top products');
      
      // Count occurrences of each product
      Map<String, int> productCounts = {};
      Map<String, String> productNames = {};
      Map<String, double> productRevenue = {};
      
      // Process each order - filter for completed orders in memory
      for (var doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        final paymentStatus = (data['paymentStatus'] as String?)?.toLowerCase() ?? '';
        
        // Skip orders that aren't completed and paid
        if (status != 'completed' || paymentStatus != 'paid') {
          continue;
        }
        
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
      
      print('SalesService: Found ${result.length} top products');
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
      // Use a simpler query to avoid index issues
      final snapshot = await _orders
        .where('merchantId', isEqualTo: currentUserId)
        .get();
      
      // Convert to OrderModel list
      final orders = snapshot.docs.map((doc) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort in memory by createdAt
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // Apply limit
      final limitedOrders = orders.length > limit ? orders.sublist(0, limit) : orders;
      
      print('SalesService: Returning ${limitedOrders.length} latest transactions');
      return limitedOrders;
    } catch (e) {
      print('Error getting latest transactions: $e');
      return [];
    }
  }
} 