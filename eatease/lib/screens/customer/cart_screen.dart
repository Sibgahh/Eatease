import 'package:flutter/material.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'checkout_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService();
  final currencyFormat = NumberFormat("#,###", "id_ID");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          if (_cartService.itemCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearCartDialog(),
              tooltip: 'Clear Cart',
            ),
        ],
      ),
      body: StreamBuilder<List<CartItemModel>>(
        stream: _cartService.cartStream,
        initialData: _cartService.items,
        builder: (context, snapshot) {
          final cartItems = snapshot.data ?? [];
          
          if (cartItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some delicious food to your cart',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Continue Shopping'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cartItems.length,
                  itemBuilder: (context, index) {
                    final item = cartItems[index];
                    return _buildCartItem(item);
                  },
                ),
              ),
              _buildCartSummary(cartItems),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: 1,
        userRole: 'customer',
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    // Find how many instances of this product exist in the cart
    final similarProductsCount = _cartService.items
        .where((cartItem) => cartItem.product.id == item.product.id)
        .length;
    
    // Calculate the index of this specific product variation
    final productVariationIndex = _cartService.items
        .where((cartItem) => cartItem.product.id == item.product.id)
        .toList()
        .indexWhere((cartItem) => cartItem.id == item.id) + 1;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with variation badge if multiple variations exist
            Stack(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item.product.imageUrls.isNotEmpty
                      ? Image.network(
                          item.product.imageUrls.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported, color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                ),
                
                // Variation badge if multiple variations exist
                if (similarProductsCount > 1)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#$productVariationIndex',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Merchant name as caption
                  FutureBuilder<String>(
                    future: _getMerchantName(item.product.merchantId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Local Restaurant',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  
                  // Product name
                  Text(
                    item.product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  
                  // Selected options (customizations)
                  if (item.selectedOptions != null && item.selectedOptions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: item.selectedOptions!.map((option) {
                        // Try to find the price for this option
                        double optionPrice = 0.0;
                        if (item.product.customizations != null) {
                          for (var category in item.product.customizations!.keys) {
                            final dynamic categoryData = item.product.customizations![category];
                            if (categoryData is Map && categoryData['options'] is List) {
                              final optionsList = categoryData['options'] as List;
                              final pricesList = categoryData['prices'] as List?;
                              
                              for (var i = 0; i < optionsList.length; i++) {
                                dynamic listItem = optionsList[i];
                                
                                if (listItem is Map && listItem['name'] == option && listItem['price'] != null) {
                                  optionPrice = (listItem['price'] as num).toDouble();
                                  break;
                                } else if (listItem == option && pricesList != null && i < pricesList.length) {
                                  if (pricesList[i] is num) {
                                    optionPrice = (pricesList[i] as num).toDouble();
                                    break;
                                  }
                                }
                              }
                            }
                          }
                        }
                        
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                option,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (optionPrice > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '+${currencyFormat.format(optionPrice.toInt())}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  // Special instructions
                  if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Note: ${item.specialInstructions}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  
                  // Price & quantity controls
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      Text(
                        'Rp ${currencyFormat.format(_calculateItemTotal(item).toInt())}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      
                      // Quantity controls
                      Row(
                        children: [
                          // Remove button
                          _buildQuantityButton(
                            icon: Icons.remove,
                            onPressed: () => _cartService.decrementQuantity(item.id),
                          ),
                          
                          // Quantity display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          
                          // Add button
                          _buildQuantityButton(
                            icon: Icons.add,
                            onPressed: () => _cartService.incrementQuantity(item.id),
                          ),
                          
                          const SizedBox(width: 8),
                          
                          // Delete button
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => _cartService.removeItem(item.id),
                            iconSize: 22,
                            splashRadius: 24,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onPressed}) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  Widget _buildCartSummary(List<CartItemModel> items) {
    final subtotal = items.fold(0.0, (sum, item) => sum + _calculateItemTotal(item));
    final deliveryFee = 0.0; // You can implement delivery fee calculation here
    final total = subtotal + deliveryFee;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              Text(
                'Rp ${currencyFormat.format(subtotal.toInt())}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Delivery fee (if applicable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Delivery Fee',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              Text(
                deliveryFee > 0 ? 'Rp ${currencyFormat.format(deliveryFee.toInt())}' : 'FREE',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: deliveryFee > 0 ? Colors.black : Colors.green,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          
          // Total amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Rp ${currencyFormat.format(total.toInt())}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Checkout button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (items.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your cart is empty'),
                    ),
                  );
                  return;
                }
                
                // Navigate to checkout screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckoutScreen(
                      items: items,
                      subtotal: subtotal,
                      deliveryFee: deliveryFee,
                      total: total,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Proceed to Checkout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to remove all items from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _cartService.clearCart();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<String> _getMerchantName(String merchantId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(merchantId).get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['storeName'] ?? doc.data()!['displayName'] ?? 'Local Restaurant';
      }
      return 'Local Restaurant';
    } catch (e) {
      print('Error fetching merchant name: $e');
      return 'Local Restaurant';
    }
  }

  double _calculateItemTotal(CartItemModel item) {
    return item.totalPrice;
  }
} 