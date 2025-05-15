import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cart_item_model.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/cart_service.dart';
import 'order_confirmation_screen.dart';
import 'payment_screen.dart';
import 'dart:math';

class CheckoutScreen extends StatefulWidget {
  final List<CartItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double total;

  const CheckoutScreen({
    Key? key,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
  }) : super(key: key);

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AuthService _authService = AuthService();
  final OrderService _orderService = OrderService();
  final PaymentService _paymentService = PaymentService();
  final CartService _cartService = CartService();
  final currencyFormat = NumberFormat("#,###", "id_ID");
  
  // Form controllers
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();
  
  // Payment options
  final List<String> _paymentMethods = ['Midtrans Payment Gateway', 'Cash on Delivery'];
  String _selectedPaymentMethod = 'Midtrans Payment Gateway';
  
  // Delivery options
  final List<String> _deliveryOptions = ['Eat in Place', 'Class Delivery'];
  String _selectedDeliveryOption = 'Eat in Place';
  
  // Promo code - keeping for compatibility but not showing in UI
  final _promoController = TextEditingController();
  String? _appliedPromo;
  double _promoDiscount = 0.0;
  
  bool _isLoading = false;
  bool _showAddressField = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Initialize address field visibility based on delivery option
    _showAddressField = _selectedDeliveryOption == 'Class Delivery';
  }
  
  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose(); // Keep for compatibility
    _noteController.dispose();
    _promoController.dispose();
    super.dispose();
  }
  
  // Load user data to pre-fill form fields
  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      try {
        final userData = await _authService.getUserData(user.uid);
        if (userData != null) {
          setState(() {
            _addressController.text = userData['address'] ?? '';
            // Phone number field removed, so no need to set it
          });
        }
      } catch (e) {
        print('Error loading user data: $e');
      }
    }
  }
  
  // Handle promo code application
  void _applyPromoCode() {
    // Method is kept for compatibility but does nothing since promo UI is removed
    return;
  }
  
  // Calculate final price after promo discount
  double get _finalTotal => max(0, widget.total - _promoDiscount);
  
  // Place order
  Future<void> _placeOrder() async {
    // Only validate address for Class Delivery option
    if (_selectedDeliveryOption == 'Class Delivery' && _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      // Create order items
      final orderItems = widget.items.map((item) => OrderItem(
        name: item.product.name,
        price: item.product.price,
        quantity: item.quantity,
        productId: item.product.id,
        options: item.selectedOptions,
        specialInstructions: item.specialInstructions,
        imageUrl: item.product.imageUrls.isNotEmpty ? item.product.imageUrls.first : null,
      )).toList();
      
      // Create order
      final order = OrderModel(
        id: '',  // Will be set by Firestore
        customerId: user.uid,
        customerName: user.displayName ?? 'Customer',
        merchantId: widget.items.first.product.merchantId,  // Assuming all items from same merchant
        merchantName: '',  // Will be fetched from merchant data
        items: orderItems,
        totalAmount: _finalTotal,
        subtotal: widget.subtotal,
        deliveryFee: widget.deliveryFee,
        discount: _promoDiscount,
        status: _selectedPaymentMethod == 'Cash on Delivery' ? 'pending' : 'awaiting_payment',
        paymentStatus: _selectedPaymentMethod == 'Cash on Delivery' ? 'pending' : 'unpaid',
        paymentMethod: _selectedPaymentMethod,
        deliveryAddress: _selectedDeliveryOption == 'Class Delivery' ? _addressController.text : 'Eat in Place',
        customerPhone: '',  // Empty string since we removed the phone field
        customerNote: _noteController.text,
        deliveryOption: _selectedDeliveryOption,
        promoCode: _appliedPromo,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Create the order in Firebase
      final orderId = await _orderService.createOrder(order);
      
      setState(() {
        _isLoading = false;
      });
      
      // Process based on payment method
      if (_selectedPaymentMethod == 'Midtrans Payment Gateway') {
        // Create payment transaction with Midtrans
        final orderWithId = order.copyWith(id: orderId);
        final paymentResult = await _paymentService.createTransaction(orderWithId);
        
        if (paymentResult['success']) {
          // Navigate to payment screen
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentScreen(
                order: orderWithId,
                orderId: orderId,
                redirectUrl: paymentResult['redirect_url'],
              ),
            ),
          );
        } else {
          // Show error
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment error: ${paymentResult['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // For COD, just go to confirmation
        _cartService.clearCart(); // Clear cart for COD orders
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderConfirmationScreen(
              orderId: orderId,
            ),
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to update visibility of address field
  void _updateAddressFieldVisibility(String? deliveryOption) {
    if (deliveryOption != null) {
      setState(() {
        _selectedDeliveryOption = deliveryOption;
        _showAddressField = deliveryOption == 'Class Delivery';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Options
                    _buildSectionTitle('Delivery Options'),
                    const SizedBox(height: 12),
                    
                    // Delivery option radio buttons
                    Column(
                      children: _deliveryOptions.map((option) => RadioListTile<String>(
                        title: Text(option),
                        subtitle: Text(option == 'Class Delivery' 
                          ? 'Delivered to your classroom' 
                          : 'Eat at the restaurant'),
                        value: option,
                        groupValue: _selectedDeliveryOption,
                        onChanged: _updateAddressFieldVisibility,
                        activeColor: AppTheme.primaryColor,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Delivery Info Section - Only show when Class Delivery is selected
                    if (_showAddressField) ...[
                      _buildSectionTitle('Delivery Information'),
                      const SizedBox(height: 16),
                      
                      // Address
                      TextField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Delivery Address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Phone Number field removed
                    
                    // Payment Method
                    _buildSectionTitle('Payment Method'),
                    const SizedBox(height: 12),
                    
                    // Payment method radio buttons
                    Column(
                      children: _paymentMethods.map((method) => RadioListTile<String>(
                        title: Text(method),
                        value: method,
                        groupValue: _selectedPaymentMethod,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedPaymentMethod = value;
                            });
                          }
                        },
                        activeColor: AppTheme.primaryColor,
                      )).toList(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Additional Notes
                    _buildSectionTitle('Additional Notes'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: 'Special Instructions (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    // Order Summary
                    _buildSectionTitle('Order Summary'),
                    const SizedBox(height: 16),
                    
                    // Order Items
                    ...widget.items.map((item) => _buildOrderItemRow(item)),
                    
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Summary Details
                    _buildSummaryRow('Subtotal', widget.subtotal),
                    const SizedBox(height: 8),
                    _buildSummaryRow('Delivery Fee', widget.deliveryFee, isGreen: widget.deliveryFee == 0),
                    if (_promoDiscount > 0) ...[
                      const SizedBox(height: 8),
                      _buildSummaryRow('Discount', _promoDiscount, isDiscount: true),
                    ],
                    const SizedBox(height: 12),
                    
                    // Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Rp ${currencyFormat.format(_finalTotal.toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Place Order Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _placeOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Place Order',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  // Helper method to build section titles
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  // Helper method to build summary rows
  Widget _buildSummaryRow(String label, double amount, {bool isDiscount = false, bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
          ),
        ),
        Text(
          isDiscount
              ? '- Rp ${currencyFormat.format(amount.toInt())}'
              : amount > 0 
                  ? 'Rp ${currencyFormat.format(amount.toInt())}' 
                  : 'FREE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDiscount 
                ? Colors.red 
                : isGreen 
                    ? Colors.green 
                    : Colors.black,
          ),
        ),
      ],
    );
  }
  
  // Helper method to build order item rows
  Widget _buildOrderItemRow(CartItemModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 60,
              child: item.product.imageUrls.isNotEmpty
                  ? Image.network(
                      item.product.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.selectedOptions!.join(', '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Note: ${item.specialInstructions}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Price and quantity
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rp ${currencyFormat.format((item.product.price * item.quantity).toInt())}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${item.quantity}x',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 