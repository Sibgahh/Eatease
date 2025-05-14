import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  // Static favorites that persists across instances
  static ValueNotifier<Set<String>> favoritesNotifier = ValueNotifier<Set<String>>({});

  // Add a debug method to print the current favorites
  static void debugPrintFavorites() {
    print('DEBUG FAVORITES: Currently ${favoritesNotifier.value.length} favorites: ${favoritesNotifier.value.toList()}');
  }

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
  
  // Scroll controller for implementing scroll-based pagination
  final ScrollController _scrollController = ScrollController();
  
  // Pagination variables
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  int _currentPage = 1;
  final int _productsPerPage = 10;
  
  // Optimized product storage
  final Map<String, ProductModel> _productsCache = {};
  List<ProductModel>? _displayedProducts;
  
  // Store open status cache to avoid repeated network calls
  final Map<String, bool> _storeOpenStatusCache = {};
  
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

  final List<Map<String, String>> _bannerImages = [
    {
      'image': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
      'title': 'Delicious Food',
    },
    {
      'image': 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800',
      'title': 'Fine Dining',
    },
    {
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800',
      'title': 'Restaurant Experience',
    },
    {
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
      'title': 'Gourmet Delights',
    },
  ];

  int _currentBannerIndex = 0;

  List<ProductModel>? _cachedProducts;
  String _lastSearchQuery = '';
  String _lastSelectedCategory = 'All';

  String? _userRole;
  bool _isLoadingRole = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    print('CUSTOMER HOME: Initializing customer home screen');
    
    // Make sure the static favorites notifier is initialized
    if (CustomerHomeScreen.favoritesNotifier.value.isEmpty) {
      print('CUSTOMER HOME: Initializing empty favorites notifier');
      CustomerHomeScreen.favoritesNotifier = ValueNotifier<Set<String>>({});
    }
    
    // Load favorites
    _loadFavorites().then((_) {
      print('CUSTOMER HOME: Favorites loaded in initState');
      CustomerHomeScreen.debugPrintFavorites();
      
      if (mounted) {
        setState(() {
          // Trigger a rebuild once favorites are loaded
        });
      }
    });
    
    _initializeData();
    _loadUserRole();
    
    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }
  
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore && _hasMoreProducts) {
      _loadMoreProducts();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('CUSTOMER HOME: Dependencies changed, reloading favorites');
    // Reload favorites when returning to this page
    _loadFavorites();
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    await _loadProducts();
    _applyFilters();
  }

  // Load favorites from Firestore
  Future<void> _loadFavorites() async {
    try {
      print('FAVORITES-LOAD: Loading favorites from Firestore');
      
      final user = _authService.currentUser;
      if (user == null) {
        print('FAVORITES-LOAD: No user logged in, skipping load');
        return; // Not logged in
      }
      
      print('FAVORITES-LOAD: Getting doc for user ${user.uid}');
      
      // Try to get the document with a timeout
      final docFuture = FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid)
          .get();
          
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        doc = await docFuture.timeout(const Duration(seconds: 5));
      } catch (timeoutError) {
        print('FAVORITES-LOAD: Timeout getting favorites, using cached data');
        // Return early to keep current favorites
        return;
      }
      
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('favorites')) {
        final List<dynamic> favoritesData = doc.data()!['favorites'] ?? [];
        // Convert to a list of strings, filtering out any non-string values
        final List<String> favorites = favoritesData
            .where((item) => item is String)
            .map((item) => item as String)
            .toList();
            
        print('FAVORITES-LOAD: Loaded ${favorites.length} favorites from Firestore: $favorites');
        
        // Update the notifier to trigger UI updates
        _favoriteItemsNotifier.value = Set<String>.from(favorites);
        
        print('FAVORITES-LOAD: Updated notifier with values: ${_favoriteItemsNotifier.value}');
        CustomerHomeScreen.debugPrintFavorites();
      } else {
        print('FAVORITES-LOAD: No favorites found in Firestore, setting empty set');
        // Reset to empty if Firestore has no data
        _favoriteItemsNotifier.value = {}; 
      }
    } catch (e) {
      print('FAVORITES-LOAD: Error loading favorites: $e');
      print('FAVORITES-LOAD: Stack trace: ${StackTrace.current}');
      
      // Don't clear existing favorites on error, to prevent data loss
      print('FAVORITES-LOAD: Keeping existing favorites due to error');
    }
  }
  
  // Save favorites to Firestore
  Future<void> _saveFavorites() async {
    try {
      print('FAVORITES: Attempting to save favorites');
      CustomerHomeScreen.debugPrintFavorites(); // Debug before saving
      
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
      CustomerHomeScreen.debugPrintFavorites(); // Debug after saving
    } catch (e) {
      print('FAVORITES: Error saving favorites: $e');
      print('FAVORITES: Stack trace: ${StackTrace.current}');
      
      // Show error only if we're mounted
      if (mounted) {
        // Don't show a visual error to the user, but restore the previous state if needed
        // This keeps the app experience smooth even if there's a network issue
      }
    }
  }

  // Toggle favorite status of a product
  void _toggleFavorite(String productId) {
    try {
      // Log the action
      print('TOGGLE: Starting favorite toggle for $productId');
      
      // Get the current user
      final user = _authService.currentUser;
      if (user == null) {
        print('TOGGLE: Cannot toggle - no user logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You need to be logged in to save favorites')),
        );
        return;
      }
      
      // Provide haptic feedback for immediate response
      HapticFeedback.mediumImpact();
      
      // Get current favorites (local copy)
      final currentFavorites = Set<String>.from(_favoriteItemsNotifier.value);
      final isCurrentlyFavorite = currentFavorites.contains(productId);
      
      print('TOGGLE: Current status - is favorite: $isCurrentlyFavorite');
      print('TOGGLE: Favorites before: ${currentFavorites.toList()}');
      
      // Update local UI immediately
      if (isCurrentlyFavorite) {
        currentFavorites.remove(productId);
      } else {
        currentFavorites.add(productId);
      }
      
      // Update the UI via the notifier
      _favoriteItemsNotifier.value = currentFavorites;
      
      print('TOGGLE: UI updated with new favorites: ${_favoriteItemsNotifier.value.toList()}');
      
      // Perform Firestore operation directly here
      final userFavoritesRef = FirebaseFirestore.instance
          .collection('userFavorites')
          .doc(user.uid);
      
      // Update Firestore in the background
      userFavoritesRef.set({
        'favorites': currentFavorites.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).then((_) {
        print('TOGGLE: Successfully saved favorites to Firestore');
      }).catchError((error) {
        print('TOGGLE: Error saving favorites: $error');
        // Revert the UI change on error
        if (isCurrentlyFavorite) {
          // It was favorite, add it back
          final revertedFavorites = Set<String>.from(_favoriteItemsNotifier.value);
          revertedFavorites.add(productId);
          _favoriteItemsNotifier.value = revertedFavorites;
        } else {
          // It wasn't favorite, remove it again
          final revertedFavorites = Set<String>.from(_favoriteItemsNotifier.value);
          revertedFavorites.remove(productId);
          _favoriteItemsNotifier.value = revertedFavorites;
        }
        
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update favorites: $error')),
          );
        }
      });
    } catch (e) {
      print('TOGGLE: Unexpected error: $e');
    }
  }

  void _showProductDetails(ProductModel product) {
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
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isRefreshing = true;
      });
      
      // Add timeout to prevent indefinite loading
      final products = await _productService.getAllAvailableProducts().first
          .timeout(const Duration(seconds: 10), onTimeout: () {
        print('Product loading timed out, using cached data if available');
        return _cachedProducts ?? [];
      });
      
      // Store products in memory cache for faster access
      for (var product in products) {
        _productsCache[product.id] = product;
      }
      
      setState(() {
        _cachedProducts = products;
        _isRefreshing = false;
        _currentPage = 1;
        _hasMoreProducts = products.length >= _productsPerPage;
      });
      
      // Apply current filters to the loaded products
      _applyFilters();
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isRefreshing = false;
        // Make sure we have something to display even if there's an error
        if (_cachedProducts == null) {
          _cachedProducts = [];
          _displayedProducts = [];
        }
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      // In a real implementation, you would fetch the next page from your API
      // For now, we'll simulate pagination with the existing list
      await Future.delayed(const Duration(milliseconds: 500));
      
      final nextPage = _currentPage + 1;
      final startIndex = _currentPage * _productsPerPage;
      
      // Get all filtered products first (apply the same filters)
      final allFilteredProducts = _getFilteredProducts();
      
      // Simulate end of list when we reach the end of our data
      if (allFilteredProducts.isNotEmpty && startIndex < allFilteredProducts.length) {
        final endIndex = (startIndex + _productsPerPage <= allFilteredProducts.length) 
            ? startIndex + _productsPerPage 
            : allFilteredProducts.length;
        
        // Get the next page of products
        final moreProducts = allFilteredProducts.sublist(startIndex, endIndex);
        
        // Load merchant data and sort properly
        _loadMerchantDataForProducts(moreProducts).then((productsWithStoreStatus) {
          // Sort with open stores first, closed stores at the bottom
          productsWithStoreStatus.sort((a, b) {
            final isOpenA = a['isOpen'] as bool;
            final isOpenB = b['isOpen'] as bool;
            
            // Sort by isOpen status (true first, false last)
            if (isOpenA != isOpenB) {
              return isOpenA ? -1 : 1;
            }
            
            // If both have same status, use the original sorting by name
            final productA = a['product'] as ProductModel;
            final productB = b['product'] as ProductModel;
            return productA.name.compareTo(productB.name);
          });
          
          // Extract just the product models from the sorted list
          final sortedMoreProducts = productsWithStoreStatus.map((item) => item['product'] as ProductModel).toList();
          
          setState(() {
            _currentPage = nextPage;
            _hasMoreProducts = endIndex < allFilteredProducts.length;
            
            // Add to displayed products
            if (_displayedProducts != null) {
              _displayedProducts!.addAll(sortedMoreProducts);
            }
            _isLoadingMore = false;
          });
        });
      } else {
        setState(() {
          _hasMoreProducts = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more products: $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }
  
  void _applyFilters() {
    if (_cachedProducts == null) {
      setState(() {
        _displayedProducts = [];
        _isRefreshing = false;
      });
      return;
    }
    
    final filteredProducts = _cachedProducts!.where((product) {
      bool matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      bool matchesSearch = _searchQuery.isEmpty || 
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesCategory && product.isAvailable && matchesSearch;
    }).toList();
    
    // Apply initial sorting by name immediately
    filteredProducts.sort((a, b) => a.name.compareTo(b.name));
    
    // Set initial display of products without waiting for merchant data
    setState(() {
      _displayedProducts = filteredProducts.take(_productsPerPage).toList();
      _isRefreshing = false;
    });
    
    // Then load store open/closed status for all products and re-sort
    _loadMerchantDataForProducts(filteredProducts).then((productsWithStoreStatus) {
      // Sort with open stores first, closed stores at the bottom
      productsWithStoreStatus.sort((a, b) {
        final isOpenA = a['isOpen'] as bool;
        final isOpenB = b['isOpen'] as bool;
        
        // Sort by isOpen status (true first, false last)
        if (isOpenA != isOpenB) {
          return isOpenA ? -1 : 1;
        }
        
        // If both have same status, use the original sorting by name
        final productA = a['product'] as ProductModel;
        final productB = b['product'] as ProductModel;
        return productA.name.compareTo(productB.name);
      });
      
      // Extract just the product models from the sorted list
      final sortedProducts = productsWithStoreStatus.map((item) => item['product'] as ProductModel).toList();
      
      setState(() {
        // For pagination, only display first page initially
        _displayedProducts = sortedProducts.take(_productsPerPage).toList();
        _currentPage = 1;
        _hasMoreProducts = sortedProducts.length > _productsPerPage;
      });
    });
  }
  
  // Helper method to load merchant data for a list of products
  Future<List<Map<String, dynamic>>> _loadMerchantDataForProducts(List<ProductModel> products) async {
    final result = <Map<String, dynamic>>[];
    
    // Create a map to avoid duplicate merchant data requests
    final merchantDataCache = <String, Map<String, dynamic>>{};
    
    // Collect unique merchant IDs
    final Set<String> uniqueMerchantIds = products.map((p) => p.merchantId).toSet();
    
    // Batch fetch merchant data
    final futures = uniqueMerchantIds.map((id) => _getMerchantData(id));
    final merchantDataResults = await Future.wait(futures);
    
    // Create merchant data cache
    for (int i = 0; i < uniqueMerchantIds.length; i++) {
      merchantDataCache[uniqueMerchantIds.elementAt(i)] = merchantDataResults[i];
    }
    
    // Process each product with the cached merchant data
    for (final product in products) {
      final merchantData = merchantDataCache[product.merchantId]!;
      final isOpen = merchantData['isOpen'] as bool? ?? true;
      
      // Update our store open status cache for future use
      _storeOpenStatusCache[product.merchantId] = isOpen;
      
      result.add({
        'product': product,
        'isOpen': isOpen,
      });
    }
    
    return result;
  }

  List<ProductModel> _getFilteredProducts() {
    if (_cachedProducts == null) return [];
    
    return _cachedProducts!.where((product) {
      bool matchesCategory = _selectedCategory == 'All' || product.category == _selectedCategory;
      bool matchesSearch = _searchQuery.isEmpty || 
          product.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          product.description.toLowerCase().contains(_searchQuery.toLowerCase());
      
      return matchesCategory && product.isAvailable && matchesSearch;
    }).toList();
  }

  Future<void> _loadUserRole() async {
    try {
      final role = await _authService.getUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      print('Error loading user role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'customer';
          _isLoadingRole = false;
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getWelcomeMessage() {
    final greeting = _getGreeting();
    final displayName = _authService.currentUser?.displayName ?? 'Foodie';
    return '$greeting, ${displayName.split(' ')[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadProducts();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Banner Slider
                  Container(
                    width: MediaQuery.of(context).size.width,
                    child: Stack(
                      children: [
                        // Banner slider
                        FlutterCarousel(
                          items: _bannerImages.map((banner) {
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Banner image
                                Image.network(
                                  banner['image']!,
                                  fit: BoxFit.cover,
                                ),
                                // Gradient overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.3),
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                ),
                                // Banner content
                                Positioned(
                                  bottom: 20,
                                  left: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        banner['title']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black54,
                                              blurRadius: 3,
                                              offset: Offset(1, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                          options: CarouselOptions(
                            height: 250,
                            viewportFraction: 1.0,
                            autoPlay: true,
                            autoPlayInterval: const Duration(seconds: 4),
                            autoPlayAnimationDuration: const Duration(milliseconds: 800),
                            autoPlayCurve: Curves.fastOutSlowIn,
                            showIndicator: false,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _currentBannerIndex = index;
                              });
                            },
                          ),
                        ),
                        
                        // Add custom indicator manually
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _bannerImages.asMap().entries.map((entry) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentBannerIndex == entry.key
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.5),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        // Safe area top padding
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: MediaQuery.of(context).padding.top,
                            color: Colors.black.withOpacity(0.2),
                          ),
                        ),
                        
                        // App title and actions
                        Positioned(
                          top: MediaQuery.of(context).padding.top,
                          left: 0,
                          right: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                const Spacer(),
                                // Admin Panel Button (only visible to admins)
                                FutureBuilder<bool>(
                                  future: _authService.isAdmin(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                                      return const SizedBox();
                                    }
                                    
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.admin_panel_settings_rounded,
                                          color: AppTheme.primaryColor,
                                        ),
                                        onPressed: () {
                                          print('CUSTOMER HOME: Admin button pressed, navigating to admin dashboard');
                                          Navigator.pushNamed(context, '/admin');
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: AppTheme.getNeumorphismDecoration(
                              borderRadius: 50,
                              color: Colors.white,
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search for food...',
                                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondaryColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              onChanged: _onSearchChanged,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Favorites button
                        Container(
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
                          child: IconButton(
                            icon: Icon(
                              Icons.favorite_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              _showFavorites();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Categories
                  Container(
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 16),
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
                            onTap: () => _onCategorySelected(category['name']),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Products grid
            _buildProductsGrid(),
            
            // Loading indicator for pagination
            SliverToBoxAdapter(
              child: _isLoadingMore 
                ? Container(
                    padding: const EdgeInsets.all(16.0),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  )
                : const SizedBox(),
            ),
            
            // Admin Mode Indicator (only visible to admins)
            SliverToBoxAdapter(
              child: FutureBuilder<bool>(
                future: _authService.isAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                    return const SizedBox();
                  }
                  
                  return Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.admin_panel_settings_rounded,
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
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isLoadingRole
          ? const SizedBox(height: 56)
          : BottomNavBar(
              currentIndex: 0,
              userRole: _userRole ?? 'customer',
            ),
    );
  }
  
  Widget _buildProductsGrid() {
    if (_isRefreshing) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading menu items...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_displayedProducts == null || _displayedProducts!.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppTheme.textSecondaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No products found',
                style: AppTheme.headingSmall(
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Pre-fetch store open status for all displayed products
    for (var product in _displayedProducts!) {
      _getStoreOpenStatus(product.merchantId);
    }
    
    // Determine grid layout based on screen width
    final double width = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;
    
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
      childAspectRatio = 0.75;
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
            final product = _displayedProducts![index];
            
            return FutureBuilder<bool>(
              // Use our cached method instead of direct call
              future: _getStoreOpenStatus(product.merchantId),
              // Default to true while loading to avoid UI flicker
              initialData: _storeOpenStatusCache[product.merchantId],
              builder: (context, snapshot) {
                final isStoreOpen = snapshot.data ?? true;
                return _ProductCard(
                  product: product,
                  currencyFormat: currencyFormat,
                  onToggleFavorite: () => _toggleFavorite(product.id),
                  onTap: () => _showProductDetails(product),
                  isStoreOpen: isStoreOpen,
                );
              }
            );
          },
          childCount: _displayedProducts!.length,
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
          'isOpen': data['isStoreActive'] ?? true,
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
                    Icons.favorite_rounded,
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
                              Icons.favorite_border_rounded,
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
                            final isFavoriteNow = favoriteIds.contains(product.id);
                            return GestureDetector(
                              onTap: () {
                                // Call the provided callback that will do the toggle
                                _toggleFavorite(product.id);
                              },
                              child: Container(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                child: Icon(
                                  isFavoriteNow
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isFavoriteNow ? Colors.red : Colors.grey.shade600,
                                  size: 20,
                                ),
                              ),
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
    final categoryData = _categories.firstWhere(
      (c) => c['name'].toLowerCase() == category.toLowerCase(),
      orElse: () => _categories[0],
    );
    return categoryData['icon'];
  }

  // Update the search and category selection methods
  void _onSearchChanged(String value) {
    if (_lastSearchQuery != value) {
      setState(() {
        _searchQuery = value;
        _lastSearchQuery = value;
        _applyFilters();
      });
    }
  }

  void _onCategorySelected(String category) {
    if (_lastSelectedCategory != category) {
      setState(() {
        _selectedCategory = category;
        _lastSelectedCategory = category;
        _applyFilters();
      });
    }
  }

  // Method to get store open status with caching
  Future<bool> _getStoreOpenStatus(String merchantId) async {
    // Check if we already have this status cached
    if (_storeOpenStatusCache.containsKey(merchantId)) {
      return _storeOpenStatusCache[merchantId]!;
    }
    
    // If not cached, fetch it and cache the result
    final merchantData = await _getMerchantData(merchantId);
    final isOpen = merchantData['isOpen'] as bool? ?? true;
    _storeOpenStatusCache[merchantId] = isOpen;
    return isOpen;
  }
}

// Extract category item to a separate stateless widget to prevent unnecessary rebuilds
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
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: isSelected ? 1.05 : 1.0),
      curve: Curves.elasticOut,
      duration: const Duration(milliseconds: 300),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? category['color'] : Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isSelected ? Colors.transparent : category['color'].withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: category['color'].withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (category['emoji'] != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        category['emoji'],
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  Text(
                    category['name'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : category['color'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Extract product card to a separate widget to prevent unnecessary rebuilds
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final NumberFormat currencyFormat;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;
  final bool isStoreOpen;

  const _ProductCard({
    required this.product,
    required this.currencyFormat,
    required this.onToggleFavorite,
    required this.onTap,
    required this.isStoreOpen,
  });

  @override
  Widget build(BuildContext context) {
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
        onTap: onTap,
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
                  // Favorite button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: CustomerHomeScreen.favoritesNotifier,
                      builder: (context, favorites, _) {
                        final isFavoriteNow = favorites.contains(product.id);
                        return GestureDetector(
                          onTap: () {
                            // Provide haptic feedback
                            HapticFeedback.lightImpact();
                            onToggleFavorite();
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
                              isFavoriteNow
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: isFavoriteNow ? Colors.red : Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Add closed indicator on the image if store is closed
                  if (!isStoreOpen)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Closed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                    // Rating stars
                    Row(
                      children: [
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
                    // Price and closed indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price
                        Text(
                          currencyFormat.format(product.price),
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        if (!isStoreOpen)
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
  
  // Helper method to get category color
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
    
    return categoryColors[category] ?? AppTheme.customerPrimaryColor;
  }
} 