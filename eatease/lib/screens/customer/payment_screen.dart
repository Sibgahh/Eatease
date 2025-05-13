import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/order_model.dart';
import '../../services/payment_service.dart';
import '../../services/order_service.dart';
import '../../utils/app_theme.dart';
import 'order_confirmation_screen.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel order;
  final String orderId;
  final String redirectUrl;

  const PaymentScreen({
    Key? key,
    required this.order,
    required this.orderId,
    required this.redirectUrl,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;
  bool _paymentCompleted = false;
  bool _paymentFailed = false;
  String _errorMessage = '';
  
  late WebViewController _controller;
  Timer? _paymentCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    
    // Start a timer to check payment status every 5 seconds
    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkPaymentStatus();
    });
  }
  
  @override
  void dispose() {
    _paymentCheckTimer?.cancel();
    super.dispose();
  }
  
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            // Handle callback URL
            if (request.url.startsWith('eatease://payment/finish')) {
              _onPaymentFinished();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.redirectUrl));
  }
  
  Future<void> _checkPaymentStatus() async {
    try {
      final result = await _paymentService.checkTransactionStatus('ORDER-${widget.orderId}');
      
      if (result['success']) {
        // If payment is complete (settlement or capture)
        if (result['status'] == 'settlement' || result['status'] == 'capture') {
          setState(() {
            _paymentCompleted = true;
          });
          _paymentCheckTimer?.cancel();
          _navigateToConfirmation();
        }
        // If payment failed (deny, cancel, expire)
        else if (result['status'] == 'deny' || result['status'] == 'cancel' || result['status'] == 'expire') {
          setState(() {
            _paymentFailed = true;
            _errorMessage = 'Payment was not completed.';
          });
          _paymentCheckTimer?.cancel();
        }
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }
  }
  
  void _onPaymentFinished() {
    _checkPaymentStatus();
  }
  
  void _navigateToConfirmation() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OrderConfirmationScreen(
          orderId: widget.orderId,
        ),
      ),
    );
  }
  
  void _retryPayment() {
    setState(() {
      _paymentFailed = false;
      _isLoading = true;
    });
    
    // Reload the payment page
    _controller.loadRequest(Uri.parse(widget.redirectUrl));
  }
  
  void _cancelPayment() {
    // Cancel the order
    _orderService.cancelOrder(widget.orderId);
    
    // Go back to the checkout screen
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentFailed) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment Failed'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Payment Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage.isNotEmpty 
                      ? _errorMessage 
                      : 'There was a problem processing your payment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _cancelPayment,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _retryPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
} 