import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../services/product_service.dart';
import '../../models/product_model.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';
import 'cart_screen.dart';
import 'store_detail_screen.dart';
import 'dart:convert';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  // Static favorites that persists across instances
  static ValueNotifier<Set<String>> favoritesNotifier = ValueNotifier<Set<String>>({});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final AuthService _authService = AuthService();
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final currencyFormat = NumberFormat("#,###", "id_ID");
  
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  // Use ValueNotifier for favorites to avoid rebuilding the whole screen
  ValueNotifier<Set<String>> get _favoriteItemsNotifier => CustomerHomeScreen.favoritesNotifier;
  Set<String> get _favoriteItems => _favoriteItemsNotifier.value;
  
  final List<String> _categories = [
    'All',
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Sides',
    'Breakfast',
    'Fast Food',
  ];

  @override
  void initState() {
    super.initState();
    print('CUSTOMER HOME: Initializing customer home screen');
    // Load saved favorites from Firestore
    _loadFavorites();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('CUSTOMER HOME: Dependencies changed, reloading favorites');
    // Reload favorites when returning to this page
    _loadFavorites();
  }
  
  // Load favorites from Firestore
  Future<void> _loadFavorites() async {
    try {
      print('FAVORITES: Loading favorites from Firestore');
      final user = _authService.currentUser;
      if (user == null) {
        print('FAVORITES: No user logged in, skipping load');
        return; // Not logged in
      }
      
      print('FAVORITES: Getting doc for user ${user.uid}');
      final doc = await FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid)
          .get();
      
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('favorites')) {
        final favorites = List<String>.from(doc.data()!['favorites'] ?? []);
        print('FAVORITES: Loaded ${favorites.length} favorites from Firestore');
        _favoriteItemsNotifier.value = Set<String>.from(favorites);
        print('FAVORITES: Updated notifier with values: ${_favoriteItemsNotifier.value}');
      } else {
        print('FAVORITES: No favorites found in Firestore');
      }
    } catch (e) {
      print('FAVORITES: Error loading favorites: $e');
    }
  }
  
  // Save favorites to Firestore
  Future<void> _saveFavorites() async {
    try {
      print('FAVORITES: Attempting to save favorites');
      final user = _authService.currentUser;
      if (user == null) {
        print('FAVORITES: No user logged in, skipping save');
        return; // Not logged in
      }
      
      final favorites = _favoriteItemsNotifier.value.toList();
      print('FAVORITES: Saving ${favorites.length} favorites to Firestore: $favorites');
      
      await FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid)
          .set({
            'favorites': favorites,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      
      print('FAVORITES: Successfully saved favorites to Firestore');
    } catch (e) {
      print('FAVORITES: Error saving favorites: $e');
    }
  }

  // Toggle favorite status of a product
  void _toggleFavorite(String productId) {
    final currentFavorites = Set<String>.from(_favoriteItems);
    if (currentFavorites.contains(productId)) {
      currentFavorites.remove(productId);
    } else {
      currentFavorites.add(productId);
    }
    _favoriteItemsNotifier.value = currentFavorites;
    
    // Save favorites to Firestore
    _saveFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('CUSTOMER HOME: Building customer home screen');
    
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 24),
            SizedBox(width: 8),
            Text(
              'EatEase',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          // Favorites button
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              _showFavorites();
            },
            tooltip: 'Favorites',
          ),
          // Admin Panel Button (only visible to admins)
          FutureBuilder<bool>(
            future: _authService.isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                return const SizedBox();
              }
              
              return IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                onPressed: () {
                  print('CUSTOMER HOME: Admin button pressed, navigating to admin dashboard');
                  Navigator.pushNamed(context, '/admin');
                },
                tooltip: 'Admin Dashboard',
              );
            },
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Welcome card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String?>(
                        future: _authService.getCurrentUserName(),
                        builder: (context, snapshot) {
                          final userName = snapshot.data ?? 'Guest';
                          return Text(
                            'Halo, $userName!',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'What would you like to eat today?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search for food...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),

          // Category Selector
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    "Categories",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 55,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = category;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppTheme.primaryColor : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ] : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                              border: Border.all(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getCategoryIcon(category),
                                  size: 16,
                                  color: isSelected ? Colors.white : Colors.grey.shade700,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category,
                                  style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  );
                },
              ),
                ),
              ],
            ),
          ),
          
          // Products Grid
          Expanded(
            child: StreamBuilder<List<ProductModel>>(
              stream: _productService.getAllAvailableProducts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }
                
                final allProducts = snapshot.data ?? [];
                
                // Filter products by category and search query
                final filteredProducts = allProducts.where((product) {
                  bool matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
                  bool matchesSearch = _searchQuery.isEmpty || 
                      product.name.toLowerCase().contains(_searchQuery) || 
                      product.description.toLowerCase().contains(_searchQuery);
                  
                  return matchesCategory && product.isAvailable && matchesSearch;
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
                              ? 'No food items matching "$_searchQuery"'
                              : 'No food items available in this category',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ValueListenableBuilder<Set<String>>(
                  valueListenable: _favoriteItemsNotifier, 
                  builder: (context, _, __) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.78,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return _buildFoodItemCard(product);
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          // Admin Mode Indicator (only visible to admins)
          FutureBuilder<bool>(
            future: _authService.isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                return const SizedBox();
              }
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  border: Border(top: BorderSide(color: Colors.amber.shade300)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Admin Mode: Viewing as customer',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/admin');
                      },
                      child: const Text('Back to Admin'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'customer';
          return BottomNavBar(
            currentIndex: 0,
            userRole: userRole,
          );
        },
      ),
    );
  }
  
  Widget _buildFoodItemCard(ProductModel product) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to the store details screen
          _getMerchantData(product.merchantId).then((merchantData) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreDetailScreen(
                  merchantId: product.merchantId,
                  merchantName: merchantData['name'] ?? 'Local Restaurant',
                  merchantImage: merchantData['image'] ?? '',
                  merchantAddress: merchantData['address'] ?? 'No address available',
                  merchantRating: merchantData['rating'] ?? 4.5,
                  merchantReviewCount: merchantData['reviewCount'] ?? 0,
                  isOpen: merchantData['isOpen'] ?? true,
                  merchantCategory: merchantData['category'] ?? 'Restaurant',
                ),
              ),
            );
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store name header
            FutureBuilder<Map<String, dynamic>>(
              future: _getMerchantData(product.merchantId),
              builder: (context, snapshot) {
                final merchantName = snapshot.data?['name'] ?? 'Local Restaurant';
                return Container(
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
                          merchantName,
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
                );
              },
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
                            _toggleFavorite(product.id);
                          },
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ValueListenableBuilder<Set<String>>(
                              valueListenable: _favoriteItemsNotifier,
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
                        'Rp ${currencyFormat.format(product.price.toInt())}',
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
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            ' (120)',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade500,
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

  // Get merchant data
  Future<Map<String, dynamic>> _getMerchantData(String merchantId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(merchantId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        return {
          'name': data['storeName'] ?? data['displayName'] ?? 'Local Restaurant',
          'image': data['bannerImageUrl'] ?? data['photoURL'] ?? '',
          'address': data['storeAddress'] ?? 'No address available',
          'rating': data['rating']?.toDouble() ?? 4.5,
          'reviewCount': data['reviewCount'] ?? 0,
          'isOpen': data['isOpen'] ?? true,
          'category': data['storeCategory'] ?? 'Restaurant',
        };
      }
      return {
        'name': 'Local Restaurant',
        'image': '',
        'address': 'No address available',
        'rating': 4.5,
        'reviewCount': 0,
        'isOpen': true,
        'category': 'Restaurant',
      };
    } catch (e) {
      print('Error fetching merchant data: $e');
      return {
        'name': 'Local Restaurant',
        'image': '',
        'address': 'No address available',
        'rating': 4.5,
        'reviewCount': 0,
        'isOpen': true,
        'category': 'Restaurant',
      };
    }
  }
  
  // Show favorited items in a bottom sheet
  void _showFavorites() {
    if (_favoriteItemsNotifier.value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You haven\'t favorited any items yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    // Show modal with ValueListenableBuilder for live updates
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Favorite Items',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              
              // Favorite items list with ValueListenableBuilder
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: _favoriteItemsNotifier,
                  builder: (context, favoriteIds, _) {
                    if (favoriteIds.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No favorite items found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return FutureBuilder<List<ProductModel>>(
                      future: _productService.getAllAvailableProducts().first,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }
                        
                        final allProducts = snapshot.data ?? [];
                        final favoriteProducts = allProducts
                            .where((product) => favoriteIds.contains(product.id))
                            .toList();
                        
                        if (favoriteProducts.isEmpty) {
                          return const Center(
                            child: Text('No favorite products available'),
                          );
                        }
                        
                        return ListView.builder(
                          itemCount: favoriteProducts.length,
                          itemBuilder: (context, index) {
                            final product = favoriteProducts[index];
                            return _buildFavoriteItem(product);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Build a single favorite item card
  Widget _buildFavoriteItem(ProductModel product) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _getMerchantData(product.merchantId).then((merchantData) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreDetailScreen(
                  merchantId: product.merchantId,
                  merchantName: merchantData['name'] ?? 'Local Restaurant',
                  merchantImage: merchantData['image'] ?? '',
                  merchantAddress: merchantData['address'] ?? 'No address available',
                  merchantRating: merchantData['rating'] ?? 4.5,
                  merchantReviewCount: merchantData['reviewCount'] ?? 0,
                  isOpen: merchantData['isOpen'] ?? true,
                  merchantCategory: merchantData['category'] ?? 'Restaurant',
                ),
              ),
            );
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(
                          product.imageUrls.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 24,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getMerchantData(product.merchantId),
                      builder: (context, snapshot) {
                        final merchantName = snapshot.data?['name'] ?? 'Local Restaurant';
                        return Text(
                          merchantName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Rp ${currencyFormat.format(product.price.toInt())}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<Set<String>>(
                          valueListenable: _favoriteItemsNotifier,
                          builder: (context, favoriteIds, _) {
                            return IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  favoriteIds.contains(product.id) ? 
                                    Icons.favorite : Icons.favorite_border,
                                  color: favoriteIds.contains(product.id) ? 
                                    Colors.red : Colors.grey.shade600,
                                  key: ValueKey<bool>(favoriteIds.contains(product.id)),
                                ),
                              ),
                              onPressed: () {
                                _toggleFavorite(product.id);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.restaurant_menu;
      case 'appetizer':
        return Icons.tapas;
      case 'main course':
        return Icons.dinner_dining;
      case 'dessert':
        return Icons.cake;
      case 'beverage':
        return Icons.local_cafe;
      case 'sides':
        return Icons.rice_bowl;
      case 'breakfast':
        return Icons.egg;
      case 'fast food':
        return Icons.fastfood;
      default:
        return Icons.category;
    }
  }
} 