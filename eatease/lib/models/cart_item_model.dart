import 'product_model.dart';

class CartItemModel {
  final String id;
  final ProductModel product;
  final int quantity;
  final List<String>? selectedOptions;
  final String? specialInstructions;

  CartItemModel({
    required this.id,
    required this.product,
    required this.quantity,
    this.selectedOptions,
    this.specialInstructions,
  });

  // Calculate the price for all selected customizations
  double get customizationsPrice {
    double customizationPrice = 0.0;
    
    if (selectedOptions != null && 
        selectedOptions!.isNotEmpty &&
        product.customizations != null) {
      
      // Loop through each selected option
      for (var option in selectedOptions!) {
        // Check each customization category
        for (var category in product.customizations!.keys) {
          final dynamic categoryData = product.customizations![category];
          
          // Handle different structure formats
          if (categoryData is Map && categoryData['options'] is List) {
            final optionsList = categoryData['options'] as List;
            final pricesList = categoryData['prices'] as List?;
            
            // Look for the option in this category
            for (var i = 0; i < optionsList.length; i++) {
              dynamic listItem = optionsList[i];
              
              if (listItem is Map && listItem['name'] == option && listItem['price'] != null) {
                // Option is a Map with a price field
                customizationPrice += (listItem['price'] as num).toDouble();
                break;
              } else if (listItem == option && pricesList != null && i < pricesList.length) {
                // Option is a String, get price from separate prices list
                if (pricesList[i] is num) {
                  customizationPrice += (pricesList[i] as num).toDouble();
                  break;
                }
              }
            }
          }
        }
      }
    }
    
    return customizationPrice;
  }

  // Total price for this cart item including customizations
  double get totalPrice => (product.price + customizationsPrice) * quantity;

  // Create a copy with updated fields
  CartItemModel copyWith({
    String? id,
    ProductModel? product,
    int? quantity,
    List<String>? selectedOptions,
    String? specialInstructions,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  // Increase quantity by one
  CartItemModel incrementQuantity() {
    return copyWith(quantity: quantity + 1);
  }

  // Decrease quantity by one (min 1)
  CartItemModel decrementQuantity() {
    if (quantity <= 1) return this;
    return copyWith(quantity: quantity - 1);
  }
} 