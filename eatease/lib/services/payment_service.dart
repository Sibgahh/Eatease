import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/order_model.dart';
import 'order_service.dart';

class PaymentService {
  // Sandbox URLs - Replace with production URLs for release
  static const String _baseUrl = 'https://api.sandbox.midtrans.com/v2';
  static const String _snapUrl = 'https://app.sandbox.midtrans.com/snap/v1/transactions';
  
  // Midtrans sandbox server key
  static const String _serverKey = 'SB-Mid-server-GC7_In1DfQC801bnaWDzl4Jf';
  
  final OrderService _orderService = OrderService();
  
  // Create a payment transaction with Midtrans
  Future<Map<String, dynamic>> createTransaction(OrderModel order) async {
    try {
      // Prepare order items for Midtrans
      final items = order.items.map((item) => {
        'id': item.productId,
        'price': item.price.toInt(),
        'quantity': item.quantity,
        'name': item.name,
      }).toList();
      
      // Calculate total from items to ensure it matches
      int itemsTotal = 0;
      for (var item in order.items) {
        itemsTotal += (item.price * item.quantity).toInt();
      }
      
      // Add delivery fee as a separate item if it exists
      if (order.deliveryFee > 0) {
        items.add({
          'id': 'delivery-fee',
          'price': order.deliveryFee.toInt(),
          'quantity': 1,
          'name': 'Delivery Fee',
        });
        itemsTotal += order.deliveryFee.toInt();
      }
      
      // Subtract discount if it exists
      int finalTotal = itemsTotal;
      if (order.discount > 0) {
        items.add({
          'id': 'discount',
          'price': -order.discount.toInt(),  // Negative value for discount
          'quantity': 1,
          'name': 'Discount',
        });
        finalTotal -= order.discount.toInt();
      }
      
      // Ensure final total is at least 1
      finalTotal = finalTotal < 1 ? 1 : finalTotal;
      
      // Create the transaction payload
      final payload = {
        'transaction_details': {
          'order_id': 'ORDER-${order.id}',
          'gross_amount': finalTotal,
        },
        'item_details': items,
        'customer_details': {
          'first_name': order.customerName,
          'phone': order.customerPhone,
          'billing_address': {
            'address': order.deliveryAddress,
          },
        },
        'callbacks': {
          'finish': 'eatease://payment/finish',
        },
      };
      
      // Call Midtrans API
      final response = await http.post(
        Uri.parse(_snapUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_serverKey:'))}',
        },
        body: jsonEncode(payload),
      );
      
      // Parse response
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 201) {
        // Return the snap token and redirect URL
        return {
          'success': true,
          'token': responseData['token'],
          'redirect_url': responseData['redirect_url'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['error_messages']?.join(', ') ?? 'Payment initialization failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating payment: $e',
      };
    }
  }
  
  // Check payment status
  Future<Map<String, dynamic>> checkTransactionStatus(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$orderId/status'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_serverKey:'))}',
        },
      );
      
      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        // Update order payment status in Firebase based on Midtrans status
        final transactionStatus = responseData['transaction_status'];
        String paymentStatus = 'pending';
        
        if (transactionStatus == 'settlement' || transactionStatus == 'capture') {
          paymentStatus = 'paid';
          // Also update order status to pending (for merchant to process)
          await _orderService.updateOrderStatusInDB(
            orderId.replaceAll('ORDER-', ''), 
            'pending'
          );
        } else if (transactionStatus == 'deny' || transactionStatus == 'cancel' || transactionStatus == 'expire') {
          paymentStatus = 'failed';
          // Cancel the order
          await _orderService.cancelOrder(orderId.replaceAll('ORDER-', ''));
        }
        
        // Update the payment status in Firebase
        await _orderService.updatePaymentStatus(
          orderId.replaceAll('ORDER-', ''), 
          paymentStatus
        );
        
        return {
          'success': true,
          'status': transactionStatus,
          'payment_status': paymentStatus,
        };
      } else {
        return {
          'success': false,
          'message': responseData['error_messages']?.join(', ') ?? 'Failed to check payment status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error checking payment status: $e',
      };
    }
  }
  
  // Show payment page in a WebView
  static Widget showPaymentWebView({
    required String redirectUrl,
    required Function(bool) onFinish,
  }) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Handle the callback URL
            if (request.url.startsWith('eatease://payment/finish')) {
              onFinish(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(redirectUrl));
      
    return WebViewWidget(controller: controller);
  }
} 