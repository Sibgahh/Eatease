import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartService {
  // Singleton pattern
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  // List of items in the cart
  final List<CartItemModel> _items = [];
  
  // Stream controller to broadcast cart changes
  final _cartController = StreamController<List<CartItemModel>>.broadcast();
  
  // Get the stream of cart items
  Stream<List<CartItemModel>> get cartStream => _cartController.stream;
  
  // Get all items in the cart
  List<CartItemModel> get items => List.unmodifiable(_items);
  
  // Get the total number of items in the cart
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  
  // Get the total price of all items in the cart
  double get totalPrice => _items.fold(0, (sum, item) => sum + item.totalPrice);

  // Add a product to the cart
  void addToCart(ProductModel product, {int quantity = 1, List<String>? selectedOptions, String? specialInstructions}) {
    // Check if the product with the same options is already in the cart
    final existingItemIndex = _items.indexWhere((item) => 
      item.product.id == product.id && 
      _areOptionsEqual(item.selectedOptions, selectedOptions) &&
      item.specialInstructions == specialInstructions
    );
    
    if (existingItemIndex >= 0) {
      // Product with same options exists, update quantity
      final existingItem = _items[existingItemIndex];
      _items[existingItemIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
    } else {
      // Add new product to the cart as a separate item
      _items.add(
        CartItemModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          product: product,
          quantity: quantity,
          selectedOptions: selectedOptions,
          specialInstructions: specialInstructions,
        ),
      );
    }
    
    // Notify listeners about the change
    _cartController.add(_items);
  }

  // Helper method to compare two lists of options
  bool _areOptionsEqual(List<String>? list1, List<String>? list2) {
    // If both are null or empty, they're equal
    if ((list1 == null || list1.isEmpty) && (list2 == null || list2.isEmpty)) {
      return true;
    }
    
    // If only one is null or empty, they're different
    if ((list1 == null || list1.isEmpty) || (list2 == null || list2.isEmpty)) {
      return false;
    }
    
    // If counts differ, they're different
    if (list1!.length != list2!.length) {
      return false;
    }
    
    // Sort both lists to ensure order-independent comparison
    final sortedList1 = List<String>.from(list1)..sort();
    final sortedList2 = List<String>.from(list2)..sort();
    
    // Compare each element
    for (int i = 0; i < sortedList1.length; i++) {
      if (sortedList1[i] != sortedList2[i]) {
        return false;
      }
    }
    
    return true;
  }

  // Update the quantity of a cart item
  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeItem(itemId);
      return;
    }
    
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      _cartController.add(_items);
    }
  }

  // Increment quantity of a cart item
  void incrementQuantity(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      _items[index] = _items[index].incrementQuantity();
      _cartController.add(_items);
    }
  }

  // Decrement quantity of a cart item
  void decrementQuantity(String itemId) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      final item = _items[index];
      if (item.quantity > 1) {
        _items[index] = item.decrementQuantity();
      } else {
        _items.removeAt(index);
      }
      _cartController.add(_items);
    }
  }

  // Remove an item from the cart
  void removeItem(String itemId) {
    _items.removeWhere((item) => item.id == itemId);
    _cartController.add(_items);
  }

  // Clear the entire cart
  void clearCart() {
    _items.clear();
    _cartController.add(_items);
  }

  // Dispose of the stream controller
  void dispose() {
    _cartController.close();
  }
} 