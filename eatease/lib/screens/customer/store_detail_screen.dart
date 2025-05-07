import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item_model.dart';
import 'cart_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final String merchantId;
  final String storeName;

  const StoreDetailScreen({
    Key? key,
    required this.merchantId,
    required this.storeName,
  }) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final ProductService _productService = ProductService();
  final CartService _cartService = CartService();
  final TextEditingController _searchController = TextEditingController();
  final currencyFormat = NumberFormat("#,###", "id_ID");
  
  String _searchQuery = '';
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
                        widget.storeName,
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
                              _storeInfo?['bannerImageUrl'] ?? 
                                'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?q=80&w=1074&auto=format&fit=crop',
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
                _storeInfo?['rating']?.toString() ?? '4.5',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_storeInfo?['reviewCount'] ?? '120'} reviews',
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
                                _storeInfo!['storeAddress'],
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
        
        // Group products by category
        final Map<String, List<ProductModel>> productsByCategory = {};
        for (var product in filteredProducts) {
          if (!productsByCategory.containsKey(product.category)) {
            productsByCategory[product.category] = [];
          }
          productsByCategory[product.category]!.add(product);
        }
        
        // Sort categories alphabetically
        final sortedCategories = productsByCategory.keys.toList()..sort();
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Extra padding at bottom for FAB
          itemCount: sortedCategories.length,
          itemBuilder: (context, index) {
            final category = sortedCategories[index];
            final categoryProducts = productsByCategory[category]!;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Container(
                  margin: const EdgeInsets.only(bottom: 12, top: 16),
                  child: Row(
                    children: [
                      Container(
                        height: 24,
                        width: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${categoryProducts.length})',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Products in this category
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: categoryProducts.length,
                  itemBuilder: (context, productIndex) {
                    return _buildProductGridItem(categoryProducts[productIndex]);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProductGridItem(ProductModel product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // Show product details
          _showProductDetails(product);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with favorite button
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.2,
                  child: product.imageUrls.isNotEmpty
                    ? Image.network(
                        product.imageUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                ),
                // Favorite button in top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () {
                        // Favorite functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${product.name} to favorites'),
                            backgroundColor: AppTheme.primaryColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(
                          Icons.favorite_border,
                          color: AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Product details with buy button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Rp ${currencyFormat.format(product.price.toInt())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      // Buy button
                      Material(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: () {
                            // Show variations selection dialog instead of directly adding to cart
                            _showVariationsDialog(product);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(
                              Icons.shopping_bag,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
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
                                      'Rp ${currencyFormat.format(product.price.toInt())}',
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
    
    // Keep track of which step we're on (customization selection or summary)
    int currentStep = 1; // 1 = Customization selection, 2 = Order summary
    
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
            
            // Validate selections before moving to summary
            bool canProceedToSummary() {
              if (!hasRequiredCustomizations) return true;
              
              updateRequiredGroups();
              return unselectedRequiredGroups.isEmpty;
            }
            
            // Go to the next step if validations pass
            void proceedToNextStep() {
              if (currentStep == 1) {
                if (canProceedToSummary()) {
                  setState(() {
                    currentStep = 2;
                  });
                } else {
                  // Show error for missing required selections
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please select options for: ${unselectedRequiredGroups.join(", ")}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            }
            
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header with close button and steps indicator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title based on current step
                        Text(
                          currentStep == 1 ? 'Customize Your Order' : 'Order Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Step indicator
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primaryColor,
                              ),
                              child: Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 16,
                              height: 2,
                              color: currentStep == 2 ? AppTheme.primaryColor : Colors.grey.shade300,
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: currentStep == 2 ? AppTheme.primaryColor : Colors.grey.shade300,
                              ),
                              child: Center(
                                child: Text(
                                  '2',
                                  style: TextStyle(
                                    color: currentStep == 2 ? Colors.white : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(),
                  
                  // Product info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        // Product image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: product.imageUrls.isNotEmpty
                            ? Image.network(
                                product.imageUrls.first,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_not_supported, color: Colors.grey),
                              ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Product details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rp ${currencyFormat.format(product.price.toInt())}',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(),
                  
                  // Main content based on current step
                  Expanded(
                    child: currentStep == 1 
                      ? _buildCustomizationStep(
                          product, 
                          hasVariations, 
                          selectedOptions, 
                          unselectedRequiredGroups,
                          setState,
                          quantity,
                          specialInstructions,
                        )
                      : _buildSummaryStep(
                          product, 
                          totalPrice, 
                          quantity, 
                          selectedOptions,
                          specialInstructions,
                          setState,
                        ),
                  ),
                  
                  // Bottom bar with action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Back button (only on step 2)
                        if (currentStep == 2)
                          TextButton.icon(
                            icon: Icon(Icons.arrow_back),
                            label: Text('Back'),
                            onPressed: () {
                              setState(() {
                                currentStep = 1;
                              });
                            },
                          )
                        else
                          Spacer(),
                          
                        // Next/Add to Cart button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: currentStep == 1
                              ? proceedToNextStep
                              : () {
                                  _cartService.addToCart(
                                    product, 
                                    quantity: quantity,
                                    selectedOptions: selectedOptions.isNotEmpty ? selectedOptions : null,
                                    specialInstructions: specialInstructions,
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ${product.name} to cart'),
                                      backgroundColor: AppTheme.primaryColor,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      action: SnackBarAction(
                                        label: 'VIEW CART',
                                        textColor: Colors.white,
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const CartScreen()),
                                          );
                                        },
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
                              elevation: 0,
                            ),
                            child: Text(
                              currentStep == 1
                                ? 'Continue to Summary'
                                : 'Add to Cart • Rp ${currencyFormat.format(totalPrice.toInt())}',
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
  
  // Build the customization selection step
  Widget _buildCustomizationStep(
    ProductModel product,
    bool hasVariations,
    List<String> selectedOptions,
    List<String> unselectedRequiredGroups,
    StateSetter setState,
    int quantity,
    String? specialInstructions,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Variations section
          if (hasVariations) ...[
            const Text(
              'Variations',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Display customization options
            ...product.customizations!.entries.map((entry) {
              final categoryName = entry.key;
              final dynamic options = entry.value;
              
              // Skip if not a map
              if (options is! Map) {
                return Container();
              }
              
              // Get options list and check if this group is required
              final isRequired = options['isRequired'] == true;
              final isUnselected = unselectedRequiredGroups.contains(categoryName);
              final optionsList = options['options'];
              
              if (optionsList is! List || optionsList.isEmpty) {
                return Container();
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUnselected ? Colors.red.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isUnselected ? Colors.red.shade200 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category name with required indicator
                    Row(
                      children: [
                        Text(
                          categoryName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isUnselected ? Colors.red : Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Required',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Options for this category
                    ...optionsList.map((option) {
                      if (option is! Map && option is! String) {
                        return Container();
                      }
                      
                      final String optionName;
                      double optionPrice = 0.0;
                      
                      if (option is Map) {
                        optionName = option['name']?.toString() ?? '';
                        optionPrice = option['price'] != null ? 
                          (option['price'] as num).toDouble() : 0.0;
                      } else {
                        optionName = option.toString();
                        
                        // Try to find the price in the 'prices' array if it exists
                        if (options['prices'] is List) {
                          final pricesList = options['prices'] as List;
                          final index = optionsList.indexOf(option);
                          if (index >= 0 && index < pricesList.length) {
                            final price = pricesList[index];
                            if (price is num) {
                              optionPrice = price.toDouble();
                            }
                          }
                        }
                      }
                      
                      if (optionName.isEmpty) {
                        return Container();
                      }
                      
                      final isSelected = selectedOptions.contains(optionName);
                      
                      return CheckboxListTile(
                        title: Text(optionName),
                        subtitle: optionPrice > 0 ? 
                          Text('+ Rp ${currencyFormat.format(optionPrice.toInt())}') : null,
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedOptions.add(optionName);
                            } else {
                              selectedOptions.remove(optionName);
                            }
                          });
                        },
                        activeColor: AppTheme.primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                        dense: true,
                      );
                    }).toList(),
                  ],
                ),
              );
            }).toList(),
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
          const SizedBox(height: 16),
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
          
          // Special instructions
          const SizedBox(height: 24),
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
              // We need to use setState here to update the variable in the outer scope
              setState(() {
                specialInstructions = value;
              });
            },
          ),
        ],
      ),
    );
  }
  
  // Build the order summary step
  Widget _buildSummaryStep(
    ProductModel product,
    double totalPrice,
    int quantity,
    List<String> selectedOptions,
    String? specialInstructions,
    StateSetter setState,
  ) {
    double basePrice = product.price;
    // Calculate options prices for display
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Summary Card
          Container(
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
                      'Rp ${currencyFormat.format(basePrice.toInt())}',
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
                              '+ Rp ${currencyFormat.format(optionPrice.toInt())}' : 
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
                
                // Special instructions
                if (specialInstructions != null && specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Special Instructions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      specialInstructions!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
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
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            if (quantity > 1) {
                              setState(() {
                                quantity--;
                              });
                            }
                          },
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              quantity++;
                            });
                          },
                        ),
                      ],
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
                      'Rp ${currencyFormat.format(totalPrice.toInt())}',
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
        ],
      ),
    );
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