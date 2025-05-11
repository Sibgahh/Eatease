import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/cart_item_model.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import 'cart_screen.dart';
import 'customer_home_screen.dart';
import 'chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    stretch: true,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                      title: Text(
                        widget.merchantName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3.0,
                              color: Color.fromARGB(150, 0, 0, 0),
                            ),
                          ],
                        ),
                      ),
                      stretchModes: const [
                        StretchMode.zoomBackground,
                        StretchMode.blurBackground,
                      ],
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Store banner image or default background
                          Hero(
                            tag: 'store-${widget.merchantId}',
                            child: Image.network(
                              widget.merchantImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.primaryColor.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Overlay gradient for better text visibility
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.1),
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    leading: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    actions: [
                      // Cart button with badge
                      StreamBuilder<List<CartItemModel>>(
                        stream: _cartService.cartStream,
                        initialData: _cartService.items,
                        builder: (context, snapshot) {
                          final cartItemCount = _cartService.itemCount;
                          
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.shopping_cart, color: Colors.white),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CartScreen()),
                                    );
                                  },
                                  tooltip: 'View Cart',
                                ),
                              ),
                              if (cartItemCount > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      cartItemCount > 9 ? '9+' : '$cartItemCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: _buildStoreInfo(),
                  ),
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
                ];
              },
              body: _buildProductsList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _startChat,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.chat, color: Colors.white),
        tooltip: 'Chat with Merchant',
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store rating and review count
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 20),
              const SizedBox(width: 4),
              Text(
                widget.merchantRating.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${widget.merchantReviewCount} reviews',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Store description
          if (_storeInfo?['storeDescription'] != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _storeInfo!['storeDescription'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ),

          const SizedBox(height: 16),
          
          // Store details in cards
          Row(
            children: [
              // Store hours
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 18, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hours',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _storeInfo?['storeHours'] ?? '8:00 - 21:00',
                              style: const TextStyle(
                                fontSize: 13,
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
              
              const SizedBox(width: 10),
              
              // Store address if available
              if (_storeInfo?['storeAddress'] != null)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.merchantAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
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
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Phone number if available
          if (_storeInfo?['phoneNumber'] != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _storeInfo!['phoneNumber'],
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton.icon(
                    icon: Icon(Icons.call, size: 16, color: AppTheme.primaryColor),
                    label: Text(
                      'Call',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: () {
                      // Implement call functionality
                    },
                  ),
                ],
              ),
            ),
            
          const Divider(height: 24),
          
          // Menu header with sorting option
          Row(
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Add sorting dropdown (can be implemented later)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, size: 16, color: Colors.grey.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Popular',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return StreamBuilder<List<ProductModel>>(
      stream: _productService.getMerchantProductsByMerchantId(widget.merchantId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'Error loading menu items',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again later',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        
        final allProducts = snapshot.data ?? [];
        
        // Filter products by search query
        final filteredProducts = allProducts.where((product) {
          bool matchesSearch = _searchQuery.isEmpty || 
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (product.category.toLowerCase().contains(_searchQuery.toLowerCase()));
          
          return matchesSearch && product.isAvailable;
        }).toList();
        
        if (filteredProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.no_food,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No menu items match your search'
                      : 'No menu items available',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear search'),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
            ),
          );
        }
        
        // Get unique categories and count items in each category
        final List<String> categories = ['All'];
        final Map<String, int> categoryCounts = {'All': filteredProducts.length};
        
        for (var product in filteredProducts) {
          if (!categories.contains(product.category)) {
            categories.add(product.category);
            categoryCounts[product.category] = 1;
          } else if (product.category != 'All') {
            categoryCounts[product.category] = (categoryCounts[product.category] ?? 0) + 1;
          }
        }
        
        // Apply category filter
        List<ProductModel> displayProducts = _selectedCategory == 'All'
            ? filteredProducts
            : filteredProducts.where((p) => p.category == _selectedCategory).toList();
        
        return Column(
          children: [
            // Category filter
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == _selectedCategory;
                  final itemCount = categoryCounts[category] ?? 0;
                  
                  // Choose an icon based on the category name
                  IconData categoryIcon = Icons.restaurant;
                  switch (category.toLowerCase()) {
                    case 'all':
                      categoryIcon = Icons.restaurant_menu;
                      break;
                    case 'appetizer':
                      categoryIcon = Icons.tapas;
                      break;
                    case 'main course':
                      categoryIcon = Icons.dinner_dining;
                      break;
                    case 'dessert':
                      categoryIcon = Icons.cake;
                      break;
                    case 'beverage':
                      categoryIcon = Icons.local_drink;
                      break;
                    case 'sides':
                      categoryIcon = Icons.rice_bowl;
                      break;
                    case 'breakfast':
                      categoryIcon = Icons.free_breakfast;
                      break;
                    case 'fast food':
                      categoryIcon = Icons.fastfood;
                      break;
                    default:
                      categoryIcon = Icons.restaurant;
                  }
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        children: [
                          Icon(
                            categoryIcon,
                            size: 18,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            category,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withOpacity(0.3) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              itemCount.toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Products grid
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                child: GridView.builder(
                  key: ValueKey<String>(_selectedCategory),
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: displayProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductGridItem(displayProducts[index]);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductGridItem(ProductModel product) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Show product details
          _showProductDetails(product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store name header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    size: 12,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.merchantName,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Product Image
            SizedBox(
              height: 90,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  product.imageUrls.isNotEmpty
                      ? Image.network(
                          product.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 32,
                            color: Colors.grey,
                          ),
                        ),
                  // Favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final currentFavorites = Set<String>.from(CustomerHomeScreen.favoritesNotifier.value);
                            final isFavorite = currentFavorites.contains(product.id);
                            
                            if (isFavorite) {
                              currentFavorites.remove(product.id);
                            } else {
                              currentFavorites.add(product.id);
                            }
                            CustomerHomeScreen.favoritesNotifier.value = currentFavorites;
                            
                            // Save favorites to Firestore
                            FirebaseFirestore.instance
                                .collection('userFavorites')
                                .doc(_authService.currentUser?.uid)
                                .set({
                              'favorites': currentFavorites.toList(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));
                          },
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ValueListenableBuilder<Set<String>>(
                              valueListenable: CustomerHomeScreen.favoritesNotifier,
                              builder: (context, favorites, _) {
                                final isFavorite = favorites.contains(product.id);
                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  switchInCurve: Curves.elasticOut,
                                  switchOutCurve: Curves.elasticIn,
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    isFavorite
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    key: ValueKey<bool>(isFavorite),
                                    color: isFavorite
                                        ? Colors.red
                                        : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Product details
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Price at the bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: Text(
                        _currencyFormat.format(product.price.toInt()),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Rating stars below price
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 12),
                          Icon(Icons.star, color: Colors.amber, size: 12),
                          Icon(Icons.star, color: Colors.amber, size: 12),
                          Icon(Icons.star, color: Colors.amber, size: 12),
                          Icon(Icons.star_half, color: Colors.amber, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '4.5',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          // Add to cart button
                          Material(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () {
                                _showVariationsDialog(product);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Icon(
                                  Icons.shopping_bag,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _showProductDetails(ProductModel product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  // Main Content
                  SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image
                        Stack(
                          children: [
                            // Product Image
                            SizedBox(
                              height: 250,
                              width: double.infinity,
                              child: product.imageUrls.isNotEmpty
                                  ? Image.network(
                                      product.imageUrls.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                            
                            // Close button
                            Positioned(
                              top: 16,
                              right: 16,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Handle indicator at top
                            Positioned(
                              top: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product name and price row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product name
                                  Expanded(
                                    child: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                      ),
                                    ),
                                  ),
                                  
                                  // Price
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Rp ${_currencyFormat.format(product.price.toInt())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Category tag
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  product.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Description header
                              const Text(
                                'Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Description text
                              Text(
                                product.description,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                  height: 1.5,
                                ),
                              ),
                              
                              const SizedBox(height: 32),
                              
                              // Add to cart button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.shopping_cart_outlined,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Add to Cart',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    // Close product details first
                                    Navigator.pop(context);
                                    // Then show variations dialog
                                    _showVariationsDialog(product);
                                  },
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                            ],
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

  // New method to show variations dialog
  void _showVariationsDialog(ProductModel product) {
    int quantity = 1;
    List<String> selectedOptions = [];
    String? specialInstructions;
    double totalPrice = product.price;
    bool hasVariations = product.customizations != null && product.customizations!.isNotEmpty;
    
    // Check if there are any required customization groups
    bool hasRequiredCustomizations = false;
    List<String> unselectedRequiredGroups = [];
    
    if (hasVariations && product.customizations != null) {
      product.customizations!.forEach((groupName, data) {
        if (data is Map && data['isRequired'] == true) {
          hasRequiredCustomizations = true;
          unselectedRequiredGroups.add(groupName);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate total price based on quantity and selected options
            double calculateTotalPrice() {
              double basePrice = product.price;
              double optionsPrice = 0;
              
              if (hasVariations && product.customizations != null) {
                for (var option in selectedOptions) {
                  final Map<String, dynamic> customizations = product.customizations!;
                  for (var category in customizations.keys) {
                    final dynamic categoryData = customizations[category];
                    
                    // Handle different structure formats
                    if (categoryData is Map) {
                      if (categoryData['options'] is List) {
                        final optionsList = categoryData['options'] as List;
                        final pricesList = categoryData['prices'] as List?;
                        
                        // Check if option is in the options list
                        for (var i = 0; i < optionsList.length; i++) {
                          dynamic listItem = optionsList[i];
                          
                          if (listItem is Map && listItem['name'] == option && listItem['price'] != null) {
                            // Option is a Map with a price field
                            optionsPrice += (listItem['price'] as num).toDouble();
                            break;
                          } else if (listItem == option && pricesList != null && i < pricesList.length) {
                            // Option is a String, get price from separate prices list
                            if (pricesList[i] is num) {
                              optionsPrice += (pricesList[i] as num).toDouble();
                              break;
                            }
                          }
                        }
                      }
                    } else if (categoryData is List) {
                      // Handle the old format or simpler structure
                      if (categoryData.contains(option)) {
                        // This is a simple list without prices, no price to add
                        continue;
                      }
                    }
                  }
                }
              }
              
              return (basePrice + optionsPrice) * quantity;
            }
            
            // Update total price
            totalPrice = calculateTotalPrice();
            
            // Check if required selections have been made
            void updateRequiredGroups() {
              if (!hasRequiredCustomizations) return;
              
              unselectedRequiredGroups.clear();
              
              product.customizations!.forEach((groupName, data) {
                if (data is Map && data['isRequired'] == true) {
                  bool hasSelectionFromThisGroup = false;
                  
                  if (data['options'] is List) {
                    for (var option in data['options']) {
                      if (option is Map && selectedOptions.contains(option['name'])) {
                        hasSelectionFromThisGroup = true;
                        break;
                      } else if (option is String && selectedOptions.contains(option)) {
                        hasSelectionFromThisGroup = true;
                        break;
                      }
                    }
                  }
                  
                  if (!hasSelectionFromThisGroup) {
                    unselectedRequiredGroups.add(groupName);
                  }
                }
              });
            }
            
            // Validate selections before adding to cart
            bool canAddToCart() {
              if (!hasRequiredCustomizations) return true;
              
              updateRequiredGroups();
              return unselectedRequiredGroups.isEmpty;
            }
            
            // Calculate option prices for display
            Map<String, double> getOptionPrices() {
              Map<String, double> optionPrices = {};
              
              if (product.customizations != null) {
                for (var option in selectedOptions) {
                  for (var category in product.customizations!.keys) {
                    final dynamic categoryData = product.customizations![category];
                    if (categoryData is Map && categoryData['options'] is List) {
                      final optionsList = categoryData['options'] as List;
                      final pricesList = categoryData['prices'] as List?;
                      
                      for (var i = 0; i < optionsList.length; i++) {
                        dynamic item = optionsList[i];
                        String itemName = '';
                        double itemPrice = 0.0;
                        
                        if (item is Map) {
                          itemName = item['name']?.toString() ?? '';
                          itemPrice = item['price'] != null ? (item['price'] as num).toDouble() : 0.0;
                        } else if (item is String) {
                          itemName = item;
                          // Try to find price in the prices list
                          if (pricesList != null && i < pricesList.length) {
                            final price = pricesList[i];
                            if (price is num) {
                              itemPrice = price.toDouble();
                            }
                          }
                        }
                        
                        if (itemName == option) {
                          optionPrices[option] = itemPrice;
                          break;
                        }
                      }
                    }
                  }
                }
              }
              
              return optionPrices;
            }
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header with close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title
                        const Text(
                          'Customize Your Order',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  const Divider(),
                  
                  // Main content (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product info
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Product image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: product.imageUrls.isNotEmpty ? 
                                    Image.network(
                                      product.imageUrls.first,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 80,
                                        height: 80,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                      ),
                                    ) : 
                                    Container(
                                      width: 80,
                                      height: 80,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                    ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Product details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Rp ${_currencyFormat.format(product.price.toInt())}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Customization options
                          if (hasVariations) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: product.customizations!.entries.map((entry) {
                                  final categoryName = entry.key;
                                  final dynamic categoryData = entry.value;
                                  final bool isRequired = categoryData is Map && categoryData['isRequired'] == true;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              categoryName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isRequired)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Required',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        
                                        // Display options based on structure
                                        if (categoryData is Map && categoryData['options'] is List) ...[
                                          Column(
                                            children: (categoryData['options'] as List).map<Widget>((option) {
                                              // Extract option details
                                              String optionName = '';
                                              double optionPrice = 0.0;
                                              
                                              if (option is Map) {
                                                optionName = option['name']?.toString() ?? '';
                                                optionPrice = option['price'] != null ? (option['price'] as num).toDouble() : 0.0;
                                              } else if (option is String) {
                                                optionName = option;
                                                // Try to find price in prices list
                                                final index = (categoryData['options'] as List).indexOf(option);
                                                if (categoryData['prices'] is List && 
                                                    index < (categoryData['prices'] as List).length) {
                                                  final price = (categoryData['prices'] as List)[index];
                                                  if (price is num) {
                                                    optionPrice = price.toDouble();
                                                  }
                                                }
                                              }
                                              
                                              if (optionName.isEmpty) {
                                                return const SizedBox.shrink();
                                              }
                                              
                                              // Check if this option is selected
                                              final bool isSelected = selectedOptions.contains(optionName);
                                              
                                              // Build checkbox for the option
                                              return CheckboxListTile(
                                                title: Text(optionName),
                                                subtitle: optionPrice > 0 ? 
                                                  Text('+ Rp ${_currencyFormat.format(optionPrice.toInt())}') : null,
                                                value: isSelected,
                                                onChanged: (bool? value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      selectedOptions.add(optionName);
                                                    } else {
                                                      selectedOptions.remove(optionName);
                                                    }
                                                    totalPrice = calculateTotalPrice();
                                                  });
                                                },
                                                activeColor: AppTheme.primaryColor,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                                                dense: true,
                                              );
                                            }).toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ] else ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'No variations available for this item',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          
                          // Quantity selector
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Quantity',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                Row(
                                  children: [
                                    Material(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () {
                                          if (quantity > 1) {
                                            setState(() {
                                              quantity--;
                                              totalPrice = calculateTotalPrice();
                                            });
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.remove, size: 20),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        quantity.toString(),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Material(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            quantity++;
                                            totalPrice = calculateTotalPrice();
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.add, size: 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Special instructions
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Special Instructions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'E.g., No onions, extra spicy',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  maxLines: 2,
                                  onChanged: (value) {
                                    setState(() {
                                      specialInstructions = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          // Order Summary
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Order Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Base price
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Base Price',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        'Rp ${_currencyFormat.format(product.price.toInt())}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Selected options
                                  if (selectedOptions.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Selected Options',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...selectedOptions.map((option) {
                                      final optionPrices = getOptionPrices();
                                      final double optionPrice = optionPrices[option] ?? 0.0;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              option,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            Text(
                                              optionPrice > 0 ? 
                                                '+ Rp ${_currencyFormat.format(optionPrice.toInt())}' : 
                                                'Included',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                  
                                  const SizedBox(height: 8),
                                  const Divider(),
                                  
                                  // Quantity
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Quantity',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'x$quantity',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  
                                  // Total
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
                                        'Rp ${_currencyFormat.format(totalPrice.toInt())}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.primaryColor,
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
                  ),
                  
                  // Add to Cart button
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (!canAddToCart()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Please select options for: ${unselectedRequiredGroups.join(", ")}'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              
                              // Add to cart
                              CartService().addToCart(
                                product,
                                quantity: quantity,
                                selectedOptions: selectedOptions,
                                specialInstructions: specialInstructions,
                              );
                              
                              Navigator.of(context).pop();
                              
                              // Show confirmation
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.name} added to cart'),
                                  action: SnackBarAction(
                                    label: 'VIEW CART',
                                    onPressed: () {
                                      Navigator.of(context).pop(); // First close the dialog
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const CartScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Add to Cart - Rp ${_currencyFormat.format(totalPrice.toInt())}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
      
      print('Starting chat - User ID: ${currentUser.uid}, Merchant ID: ${widget.merchantId}');
      
      // Create or get conversation
      final conversationId = await _chatService.createOrGetConversation(
        currentUser.uid,
        widget.merchantId,
      );
      
      print('Conversation created/retrieved with ID: $conversationId');
      
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
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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