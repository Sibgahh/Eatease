import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../models/cart_item_model.dart';
import '../../services/auth/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreDetailScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;
  final String merchantImage;
  final String merchantAddress;
  final double merchantRating;
  final int merchantReviewCount;
  final bool isOpen;
  final String merchantCategory;

  const StoreDetailScreen({
    Key? key,
    required this.merchantId,
    required this.merchantName,
    required this.merchantImage,
    required this.merchantAddress,
    required this.merchantRating,
    required this.merchantReviewCount,
    required this.isOpen,
    required this.merchantCategory,
  }) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _authService = AuthService();
  final _productService = ProductService();
  final _cartService = CartService();
  final _chatService = ChatService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  
  String _searchQuery = '';
  String _selectedCategory = 'All';
  Map<String, dynamic>? _storeInfo;
  bool _isLoading = true;
  int quantity = 1;
  String? specialInstructions;

  // List of categories with emojis and colors
  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'All',
      'emoji': '🍽️',
      'color': AppTheme.customerPrimaryColor,
    },
    {
      'name': 'Appetizer',
      'emoji': '🍲',
      'color': AppTheme.customerSecondaryColor,
    },
    {
      'name': 'Main Course',
      'emoji': '🥘',
      'color': AppTheme.customerPrimaryColor,
    },
    {
      'name': 'Dessert',
      'emoji': '🍰',
      'color': AppTheme.customerSecondaryColor,
    },
    {
      'name': 'Beverage',
      'emoji': '🥤',
      'color': AppTheme.customerPrimaryColor,
    },
    {
      'name': 'Sides',
      'emoji': '🍟',
      'color': AppTheme.customerSecondaryColor,
    },
    {
      'name': 'Breakfast',
      'emoji': '🍳',
      'color': AppTheme.customerPrimaryColor,
    },
    {
      'name': 'Fast Food',
      'emoji': '🍔',
      'color': AppTheme.customerSecondaryColor,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreInfo() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.merchantId)
          .get();
      
      if (doc.exists && doc.data() != null) {
        setState(() {
          _storeInfo = doc.data()!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading store info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Store header
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                  // Store image
                  widget.merchantImage.isNotEmpty
                      ? Image.network(
                              widget.merchantImage,
                              fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.neumorphismBackground,
                            child: const Icon(
                              Icons.store,
                              size: 64,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: AppTheme.neumorphismBackground,
                          child: const Icon(
                            Icons.store,
                                    size: 64,
                            color: Colors.grey,
                                  ),
                                ),
                  // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                          Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              title: Text(
                widget.merchantName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

          // Store info
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store name and category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.merchantName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.merchantCategory,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isOpen ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: widget.isOpen ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isOpen ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Rating and address
                  Row(
                    children: [
                      // Rating stars
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.merchantRating}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            ' (${widget.merchantReviewCount})',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 16,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      
                      // Address
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 18,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.merchantAddress,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const Divider(height: 24),
                ],
              ),
            ),
          ),

          // Add white space
          SliverToBoxAdapter(
            child: Container(
              height: 8,
              color: Colors.grey.shade50,
            ),
          ),

          // Search bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchBarDelegate(
              searchController: _searchController,
              onSearchChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Category filters
          SliverToBoxAdapter(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category['name'] == _selectedCategory;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _CategoryItem(
                      category: category,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedCategory = category['name'];
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),

          // Add white space
          SliverToBoxAdapter(
            child: Container(
              height: 16,
              color: Colors.grey.shade50,
            ),
          ),

          // Menu header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: AppTheme.headingMedium(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Sort',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Add white space
          SliverToBoxAdapter(
            child: Container(
              height: 16,
              color: Colors.grey.shade50,
            ),
          ),

          // Menu items
          StreamBuilder<List<ProductModel>>(
      stream: _productService.getMerchantProductsByMerchantId(widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
        }
        
        if (snapshot.hasError) {
                return SliverFillRemaining(
                  child: Center(
                    child: Text('Error: ${snapshot.error}'),
            ),
          );
        }
        
              final allProducts = snapshot.data ?? [];
              
              // Filter products based on category and search query
              final products = allProducts.where((product) {
                bool matchesCategory = _selectedCategory == 'All' || 
                    product.category.toLowerCase() == _selectedCategory.toLowerCase();
                bool matchesSearch = _searchQuery.isEmpty || 
                    product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    product.description.toLowerCase().contains(_searchQuery.toLowerCase());
                
                return matchesCategory && matchesSearch && product.isAvailable;
              }).toList();

              if (products.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.no_food,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          allProducts.isEmpty
                              ? 'No menu items available'
                              : 'No items found in this category',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Sort products by store open status - open stores first, closed stores at the bottom
              if (!widget.isOpen) {
                // If the store is closed, all products are treated as from a closed store
                // No need to sort as all items are from closed store
              } else {
                // If the store is open, make sure any potential items marked as 
                // unavailable or with special closed status appear at the bottom
                products.sort((a, b) {
                  // First prioritize by availability
                  if (a.isAvailable != b.isAvailable) {
                    return a.isAvailable ? -1 : 1; // Available items first
                  }
                  
                  // Then sort by other criteria if needed (like alphabetically by name)
                  return a.name.compareTo(b.name);
                });
              }
        
              final double width = MediaQuery.of(context).size.width;
              int crossAxisCount;
              double childAspectRatio;
              
              // Determine grid layout based on screen width
              if (width > 900) {
                // Large tablet
                crossAxisCount = 4;
                childAspectRatio = 0.85;
              } else if (width > 600) {
                // Medium tablet
                crossAxisCount = 3;
                childAspectRatio = 0.8;
              } else {
                // Phone
                crossAxisCount = 2;
                childAspectRatio = 0.7;
              }
              
              return SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: childAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return _buildProductCard(context, product);
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // Add floating action button for cart
      floatingActionButton: StreamBuilder<List<CartItemModel>>(
        stream: _cartService.cartStream,
        builder: (context, snapshot) {
          final cartItems = snapshot.data ?? [];
          final hasItems = cartItems.isNotEmpty;
          
          // Calculate total items in cart
          int totalItems = 0;
          if (hasItems) {
            for (var item in cartItems) {
              totalItems += item.quantity;
            }
          }
          
          // Only show FAB if there are items in cart
          return hasItems 
            ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const CartScreen()),
                  );
                },
                backgroundColor: AppTheme.primaryColor,
                elevation: 4,
                label: Row(
                  children: [
                    const Icon(Icons.shopping_cart_rounded),
                    const SizedBox(width: 8),
                    Text(
                      '$totalItems',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink();
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Widget to display individual product cards
  Widget _buildProductCard(BuildContext context, ProductModel product) {
    // Check if we're on a tablet
    final double width = MediaQuery.of(context).size.width;
    final bool isTablet = width > 600;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show product details bottom sheet
          _showProductDetails(context, product);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: isTablet ? 1.4 / 1 : 1.2 / 1, // Slightly wider for tablet
                    child: product.imageUrls.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrls.first,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                  ),
                  // Add favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: CustomerHomeScreen.favoritesNotifier,
                      builder: (context, favorites, _) {
                        final isFavorite = favorites.contains(product.id);
                        return GestureDetector(
                          onTap: () {
                            // Provide haptic feedback
                            HapticFeedback.lightImpact();
                            _toggleFavorite(product.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: isFavorite ? Colors.red : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Product details
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 8 : 6), // Slightly more padding on tablet
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 14, // Slightly larger text on tablet
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Category chip
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 8 : 6, 
                        vertical: isTablet ? 3 : 2
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(product.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getCategoryColor(product.category).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        product.category,
                        style: TextStyle(
                          fontSize: isTablet ? 11 : 9,
                          fontWeight: FontWeight.w500,
                          color: _getCategoryColor(product.category),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Rating stars (moved below category)
                    Row(
                      children: [
                        // Calculate rating (random between 3.5-5.0 based on product id hash for demo)
                        // In a real app, you'd use the actual product rating from the database
                        ...List.generate(5, (index) {
                          final rating = (product.id.hashCode % 15 + 35) / 10; // Range 3.5-5.0
                          return Icon(
                            index < rating.floor()
                                ? Icons.star
                                : (index < rating.ceil() && index >= rating.floor())
                                    ? Icons.star_half
                                    : Icons.star_border,
                            size: 10,
                            color: Colors.amber,
                          );
                        }),
                        const SizedBox(width: 2),
                        Text(
                          ((product.id.hashCode % 15 + 35) / 10).toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Price and add to cart button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          _currencyFormat.format(product.price),
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (!widget.isOpen)
                          Text(
                            'Closed',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: Colors.red.shade400,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Toggle favorite status
  void _toggleFavorite(String productId) {
    try {
      // Log the action
      print('STORE-TOGGLE: Starting favorite toggle for $productId');
      
      // Get the current user
      final user = _authService.currentUser;
      if (user == null) {
        print('STORE-TOGGLE: Cannot toggle - no user logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to save favorites')),
        );
        return;
      }
      
      // Provide haptic feedback for immediate response
      HapticFeedback.mediumImpact();
      
      // Get current favorites (local copy)
      final currentFavorites = Set<String>.from(CustomerHomeScreen.favoritesNotifier.value);
      final isCurrentlyFavorite = currentFavorites.contains(productId);
      
      print('STORE-TOGGLE: Current status - is favorite: $isCurrentlyFavorite');
      print('STORE-TOGGLE: Favorites before: ${currentFavorites.toList()}');
      
      // Update local UI immediately
      if (isCurrentlyFavorite) {
        currentFavorites.remove(productId);
      } else {
        currentFavorites.add(productId);
      }
      
      // Update the UI via the notifier
      CustomerHomeScreen.favoritesNotifier.value = currentFavorites;
      
      print('STORE-TOGGLE: UI updated with new favorites: ${CustomerHomeScreen.favoritesNotifier.value.toList()}');
      
      // Perform Firestore operation directly here
      final userFavoritesRef = FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid);
      
      // Update Firestore in the background
      userFavoritesRef.set({
        'favorites': currentFavorites.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).then((_) {
        print('STORE-TOGGLE: Successfully saved favorites to Firestore');
      }).catchError((error) {
        print('STORE-TOGGLE: Error saving favorites: $error');
        // Revert the UI change on error
        if (isCurrentlyFavorite) {
          // It was favorite, add it back
          final revertedFavorites = Set<String>.from(CustomerHomeScreen.favoritesNotifier.value);
          revertedFavorites.add(productId);
          CustomerHomeScreen.favoritesNotifier.value = revertedFavorites;
        } else {
          // It wasn't favorite, remove it again
          final revertedFavorites = Set<String>.from(CustomerHomeScreen.favoritesNotifier.value);
          revertedFavorites.remove(productId);
          CustomerHomeScreen.favoritesNotifier.value = revertedFavorites;
        }
        
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update favorites: $error')),
          );
        }
      });
    } catch (e) {
      print('STORE-TOGGLE: Unexpected error: $e');
    }
  }
  
  // Get color for a category based on the defined categories
  Color _getCategoryColor(String category) {
    final Map<String, Color> categoryColors = {
      'All': AppTheme.customerPrimaryColor,
      'Appetizer': AppTheme.customerSecondaryColor,
      'Main Course': AppTheme.customerPrimaryColor,
      'Dessert': AppTheme.customerSecondaryColor,
      'Beverage': AppTheme.customerPrimaryColor,
      'Sides': AppTheme.customerSecondaryColor,
      'Breakfast': AppTheme.customerPrimaryColor,
      'Fast Food': AppTheme.customerSecondaryColor,
    };
    
    // Find the category in the _categories list
    for (var cat in _categories) {
      if (cat['name'].toString().toLowerCase() == category.toLowerCase()) {
        return cat['color'] as Color;
      }
    }
    
    // Return default color from map or a fallback color
    return categoryColors[category] ?? AppTheme.customerPrimaryColor;
  }
  
  // Show product details
  void _showProductDetails(BuildContext context, ProductModel product) {
    // Reset quantity and special instructions
    quantity = 1;
    specialInstructions = null;
    
    // Check if we're on a tablet
    final double width = MediaQuery.of(context).size.width;
    final bool isTablet = width > 600;
    
    // Variables for the details view
    double totalPrice = product.price;
    Map<String, String> _selectedOptions = {};
    
    // Initialize selected options with defaults
    if (product.customizations != null) {
      product.customizations!.forEach((category, data) {
        if (data is Map && data['options'] is List && (data['options'] as List).isNotEmpty) {
          _selectedOptions[category] = (data['options'] as List).first.toString();
        }
      });
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            
            // Move the _updateTotalPrice function inside the builder so it can use setModalState
            void _updateTotalPrice() {
              double basePrice = product.price;
              
              // Add customization prices
              double customizationsPrice = 0;
              if (product.customizations != null) {
                _selectedOptions.forEach((category, option) {
                  if (product.customizations!.containsKey(category)) {
                    final categoryData = product.customizations![category];
                    if (categoryData is Map && 
                        categoryData['options'] is List && 
                        categoryData['prices'] is List) {
                      
                      final options = categoryData['options'] as List;
                      final prices = categoryData['prices'] as List;
                      
                      final index = options.indexOf(option);
                      if (index >= 0 && index < prices.length && prices[index] is num) {
                        customizationsPrice += (prices[index] as num).toDouble();
                      }
                    }
                  }
                });
              }
              
              // Use setModalState to update the local state
              setModalState(() {
                totalPrice = (basePrice + customizationsPrice) * quantity;
              });
            }
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  Stack(
                    children: [
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: product.imageUrls.isNotEmpty
                          ? Image.network(
                              product.imageUrls.first,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.image_not_supported,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                      ),
                      // Close button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Product details (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product name and price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _currencyFormat.format(product.price),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Category chip
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 8 : 6, 
                              vertical: isTablet ? 3 : 2
                            ),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(product.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getCategoryColor(product.category).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              product.category,
                              style: TextStyle(
                                fontSize: isTablet ? 11 : 9,
                                fontWeight: FontWeight.w500,
                                color: _getCategoryColor(product.category),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Description
                          Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Customizations section
                          if (product.customizations != null && product.customizations!.isNotEmpty) ...[
                            const Text(
                              'Customizations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                          
                            // Display customization categories
                            ...product.customizations!.entries.map((entry) {
                              final categoryName = entry.key;
                              final categoryData = entry.value;
                              
                              // Skip if data is invalid
                              if (categoryData == null || 
                                  categoryData['options'] == null || 
                                  !(categoryData['options'] is List) ||
                                  (categoryData['options'] as List).isEmpty) {
                                return const SizedBox.shrink();
                              }
                              
                              final options = categoryData['options'] as List;
                              final prices = categoryData['prices'] as List? ?? [];
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Category name
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Text(
                                        categoryName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    // Options list
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options[index].toString();
                                        final price = index < prices.length && prices[index] is num
                                            ? (prices[index] as num).toDouble()
                                            : 0.0;
                                        final isSelected = _selectedOptions[categoryName] == option;
                                        
                                        return RadioListTile<String>(
                                          title: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(option),
                                              if (price > 0)
                                                Text(
                                                  '+${_currencyFormat.format(price)}',
                                                  style: TextStyle(
                                                    color: AppTheme.primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          value: option,
                                          groupValue: _selectedOptions[categoryName],
                                          onChanged: (value) {
                                            setModalState(() {
                                              if (value != null) {
                                                _selectedOptions[categoryName] = value;
                                                _updateTotalPrice();
                                              }
                                            });
                                          },
                                          activeColor: AppTheme.primaryColor,
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                          
                          // Special instructions
                          const Text(
                            'Special Instructions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'E.g., No onions, less spicy, etc.',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: AppTheme.primaryColor),
                              ),
                            ),
                            maxLines: 2,
                            onChanged: (value) {
                              specialInstructions = value;
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  
                  // Bottom bar with quantity selector and add button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Quantity selector
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Minus button
                              IconButton(
                                icon: Icon(
                                  Icons.remove,
                                  color: quantity > 1 ? AppTheme.primaryColor : Colors.grey,
                                ),
                                onPressed: quantity > 1
                                    ? () {
                                        setModalState(() {
                                          quantity--;
                                          _updateTotalPrice();
                                        });
                                      }
                                    : null,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                              ),
                              // Quantity display
                              SizedBox(
                                width: 36,
                                child: Text(
                                  quantity.toString(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Plus button
                              IconButton(
                                icon: Icon(
                                  Icons.add,
                                  color: AppTheme.primaryColor,
                                ),
                                onPressed: () {
                                  setModalState(() {
                                    quantity++;
                                    _updateTotalPrice();
                                  });
                                },
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Add to cart button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: widget.isOpen ? () {
                              // Add item to cart
                              _addToCart(
                                product, 
                                quantity: quantity,
                                selectedOptions: _selectedOptions.values.toList(),
                                specialInstructions: specialInstructions?.isNotEmpty == true ? specialInstructions : null,
                                totalPrice: totalPrice,
                              );
                              Navigator.pop(context);
                            } : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              disabledBackgroundColor: Colors.grey.shade400,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.isOpen
                                ? 'Add to Cart - ${_currencyFormat.format(totalPrice)}'
                                : 'Store Closed',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Add product to cart
  void _addToCart(
    ProductModel product, {
    int quantity = 1,
    List<String>? selectedOptions,
    String? specialInstructions,
    double? totalPrice,
  }) {
    _cartService.addToCart(
      product,
      quantity: quantity,
      selectedOptions: selectedOptions,
      specialInstructions: specialInstructions,
      totalPrice: totalPrice,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'View Cart',
          onPressed: () {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  // Initiate a chat with the merchant
  Future<void> _startChat() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Check if current user exists
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to chat')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      // Validate merchant ID
      if (widget.merchantId.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid merchant information')),
        );
        return;
      }
      
      try {
        // Create or get conversation (will throw an exception if no active order exists)
        final conversationId = await _chatService.createOrGetConversation(
          currentUser.uid,
          widget.merchantId,
        );
        
        setState(() {
          _isLoading = false;
        });
        
        if (!mounted) return;
        
        // Navigate to chat detail screen
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              conversationId: conversationId,
              otherUserId: widget.merchantId,
              otherUserName: widget.merchantName,
            ),
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (!mounted) return;
        
        // Show a specific message to inform the user that chat is only available during active orders
        if (e.toString().contains('No active orders found')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat is only available during active orders. Please place an order first.'),
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start chat: ${e.toString()}'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _startChat: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: ${e.toString()}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}

// Category Item Widget
class _CategoryItem extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category, 
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? category['color'].withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? category['color'] : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (category['emoji'] != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  category['emoji'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            Text(
              category['name'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? category['color'] : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Search Bar Delegate
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  _SearchBarDelegate({
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
            borderSide: BorderSide(color: AppTheme.primaryColor),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              )
            : null,
        ),
        onChanged: onSearchChanged,
      ),
    );
  }

  @override
  double get maxExtent => 64;

  @override
  double get minExtent => 64;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
} 