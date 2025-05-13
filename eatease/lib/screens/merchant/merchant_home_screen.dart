import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/auth/auth_service.dart';
import '../../services/sales_service.dart';
import '../../models/merchant_model.dart';
import '../../models/order_model.dart';
import '../../utils/app_theme.dart';
import 'product_list_screen.dart';
import 'merchant_settings_screen.dart';
import 'merchant_orders_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../routes.dart';

class MerchantHomeScreen extends StatefulWidget {
  final bool showScaffold;
  
  const MerchantHomeScreen({
    super.key, 
    this.showScaffold = false
  });

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  final AuthService _authService = AuthService();
  final SalesService _salesService = SalesService();
  bool _isLoading = true;
  bool _isStoreConfigured = false;
  bool _isStoreActive = false;
  bool _isUpdatingStatus = false;
  String _merchantName = 'Merchant';
  
  // Currency formatter for Rupiah
  final NumberFormat rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  
  // Utility method to format currency in Rupiah
  String formatRupiah(double amount) {
    return rupiahFormat.format(amount);
  }
  
  // Sales statistics
  Map<String, dynamic> _salesStats = {
    'totalSales': 0.0,
    'totalOrders': 0,
    'averageOrder': 0.0,
    'todaySales': 0.0,
    'todayOrders': 0,
  };
  
  // Chart data
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _topProducts = [];
  
  // Latest transactions
  List<OrderModel> _latestTransactions = [];
  
  // Rating data
  double _rating = 4.7;
  int _reviewCount = 128;
  
  @override
  void initState() {
    super.initState();
    print('MerchantHomeScreen: initState called');
    _loadData();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('MerchantHomeScreen: didChangeDependencies called');
    // This ensures data is refreshed when navigating back to this screen
    if (!_isLoading) {
      _loadData();
    }
  }
  
  Future<void> _loadData() async {
    print('Loading merchant dashboard data');
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load merchant data - force a fresh load from the server
      await _authService.getCurrentMerchantModel(forceRefresh: true).then((merchantModel) {
        if (merchantModel != null) {
          setState(() {
            _isStoreConfigured = merchantModel.isStoreConfigured();
            _merchantName = merchantModel.displayName;
            _isStoreActive = merchantModel.isStoreActive;
          });
          
          print('Merchant data loaded, isStoreActive: ${merchantModel.isStoreActive}');
          
          if (!_isStoreConfigured && mounted) {
            // Navigate to settings screen after a short delay for setup
            Future.delayed(const Duration(milliseconds: 500), () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(
                  builder: (context) => const MerchantSettingsScreen(redirectedForSetup: true),
                ),
              );
            });
            return;
          }
        } else {
          print('No merchant data found');
        }
      });
      
      // Load sales statistics - adding print statements for debugging
      print('Fetching sales statistics...');
      
      // Clear existing data to ensure we're not showing stale data
      setState(() {
        _salesStats = {
          'totalSales': 0.0,
          'totalOrders': 0,
          'averageOrder': 0.0,
          'todaySales': 0.0,
          'todayOrders': 0,
        };
        _salesData = [];
        _topProducts = [];
        _latestTransactions = [];
      });
      
      final salesStats = await _salesService.getMerchantSalesStats();
      print('Sales stats loaded: $salesStats');
      
      final salesData = await _salesService.getMerchantSalesSummaryByDay();
      print('Sales data by day loaded: ${salesData.length} days');
      
      final topProducts = await _salesService.getTopSellingProducts();
      print('Top products loaded: ${topProducts.length} products');
      
      final latestTransactions = await _salesService.getLatestTransactions();
      print('Latest transactions loaded: ${latestTransactions.length} transactions');
      
      if (mounted) {
        // Update the state with fresh data
        setState(() {
          _salesStats = salesStats;
          _salesData = salesData;
          _topProducts = topProducts;
          _latestTransactions = latestTransactions;
          
          // Set fixed values for testing if needed
          // Uncomment this section if you need to test with fixed values
          /*
          _salesStats = {
            'totalSales': 83000.0,
            'totalOrders': 5,
            'averageOrder': 16600.0,
            'todaySales': 20000.0,
            'todayOrders': 1,
          };
          */
        });
      }
    } catch (e) {
      print('Error loading merchant dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sales data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator
    if (_isLoading) {
      return widget.showScaffold
        ? Scaffold(
            appBar: _buildAppBar(),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
    }
    
    // Build the main content
    Widget content = RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header as Card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildHeaderCard(),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store setup reminder (if not configured)
                  if (!_isStoreConfigured)
                    _buildSetupReminder(),
                    
                  // Performance Summary Card
                  const SizedBox(height: 16),
                  Text('Performance Summary', style: AppTheme.headingMedium()),
                  const SizedBox(height: 12),
                  
                  _buildPerformanceCard(),
                  
                  // Sales Chart
                  const SizedBox(height: 24),
                  Text('Sales Trend (Last 7 Days)', style: AppTheme.headingMedium()),
                  const SizedBox(height: 12),
                  _buildSalesChart(),
                  
                  // Top Products
                  const SizedBox(height: 24),
                  Text('Top Selling Products', style: AppTheme.headingMedium()),
                  const SizedBox(height: 12),
                  _buildTopProductsList(),
                  
                  // Latest Transactions
                  const SizedBox(height: 24),
                  Text('Latest Transactions', style: AppTheme.headingMedium()),
                  const SizedBox(height: 12),
                  _buildLatestTransactions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
    // Return content with or without scaffold depending on showScaffold parameter
    return widget.showScaffold
        ? Scaffold(
            appBar: _buildAppBar(),
            body: content,
          )
        : content;
  }
  
  // New method for the redesigned AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.textPrimaryColor,
      centerTitle: false,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.png', 
            height: 32,
            errorBuilder: (ctx, obj, st) => Icon(
              Icons.restaurant, 
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'EatEase Merchant',
            style: AppTheme.headingSmall(color: AppTheme.textPrimaryColor),
          ),
        ],
      ),
      actions: [
        // Admin Panel Button (only visible to admins)
        FutureBuilder<bool>(
          future: _authService.isAdmin(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
              return const SizedBox();
            }
            
            return IconButton(
              icon: Icon(
                Icons.admin_panel_settings,
                color: AppTheme.primaryColor,
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/admin');
              },
              tooltip: 'Admin Dashboard',
            );
          },
        ),
      ],
    );
  }
  
  // New method for the header card
  Widget _buildHeaderCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      Color(0xFF2E7D32), // Darker shade for depth
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
              right: -30,
              top: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
              left: -40,
              bottom: -40,
                      child: Container(
                width: 150,
                height: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Content
                    Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar or icon
                              Container(
                                width: 60,
                                height: 60,
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
                                child: Center(
                                  child: Icon(
                            Icons.store,
                                    size: 30,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Welcome text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _merchantName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        // Rating stars
                                        _buildRatingStars(_rating),
                                        const SizedBox(width: 8),
                                        // Rating text
                                        Text(
                                          '$_rating',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '($_reviewCount)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Store status toggle
                          const SizedBox(height: 20),
                          _buildStoreStatusToggle(),
                        ],
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
  
  // Build the store status toggle switch
  Widget _buildStoreStatusToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Store Status',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Text(
                _isStoreActive ? 'Open' : 'Closed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isStoreActive ? Colors.white : Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 10),
              _isUpdatingStatus
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Switch(
                    value: _isStoreActive,
                    onChanged: _toggleStoreStatus,
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green.shade300,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.red.withOpacity(0.5),
                  ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Method to toggle store status
  Future<void> _toggleStoreStatus(bool newStatus) async {
    // Exit early if already updating to prevent double-tap issues
    if (_isUpdatingStatus) {
      print('Already updating store status, ignoring tap');
      return;
    }
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    print('Toggling store status to: $newStatus');
    
    try {
      final success = await _authService.updateMerchantStoreStatus(newStatus);
      
      if (success && mounted) {
        print('Store status update successful');
        setState(() {
          _isStoreActive = newStatus;
          _isUpdatingStatus = false;
        });
        
        // Reload data to ensure we have the latest state
        await _loadData();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store is now ${newStatus ? 'open' : 'closed'}'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Handle failure
        print('Store status update failed');
        setState(() {
          _isUpdatingStatus = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update store status'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating store status: $e');
      setState(() {
        _isUpdatingStatus = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  Widget _buildSetupReminder() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
        boxShadow: AppTheme.getShadow(color: AppTheme.accentColor, opacity: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.accentColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete Your Store Setup',
                  style: AppTheme.headingSmall(color: AppTheme.accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your store is not fully configured yet. Please complete the setup to start selling products.',
            style: AppTheme.bodyMedium(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MerchantSettingsScreen(redirectedForSetup: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
              ),
              child: const Text('Complete Setup'),
            ),
          ),
        ],
      ),
    );
  }
  
  // New combined performance card
  Widget _buildPerformanceCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with refresh button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Sales Overview",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    print('Manually refreshing sales data...');
                    setState(() {
                      _isLoading = true;
                    });
                    _loadData().then((_) {
                      if (mounted) {
                        print('Sales data refreshed - Total Sales: ${_salesStats['totalSales']}');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sales data refreshed'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    });
                  },
                  tooltip: 'Refresh sales data',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Today's performance row
            Row(
              children: [
                // Today's sales
                Expanded(
                  child: _buildCompactStat(
                    AppTheme.primaryColor,
                    _salesStats['todaySales'] > 0 
                      ? formatRupiah(_salesStats['todaySales'])
                      : 'Rp 0',
                    "Today's Sales",
                    Icons.payments_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                // Today's orders
                Expanded(
                  child: _buildCompactStat(
                    AppTheme.accentColor,
                    '${_salesStats['todayOrders']}',
                    "Today's Orders",
                    Icons.shopping_bag_outlined,
                  ),
                ),
              ],
            ),
            
            // Spacer
            const SizedBox(height: 16),
            
            // Total sales & orders row
            Row(
              children: [
                // Total sales
                Expanded(
                  child: _buildCompactStat(
                    AppTheme.successColor,
                    _salesStats['totalSales'] > 0 
                      ? formatRupiah(_salesStats['totalSales'])
                      : 'Rp 0',
                    "Total Sales",
                    Icons.bar_chart,
                  ),
                ),
                const SizedBox(width: 12),
                // Total orders
                Expanded(
                  child: _buildCompactStat(
                    Colors.deepPurple,
                    '${_salesStats['totalOrders']}',
                    "Total Orders",
                    Icons.receipt_outlined,
                  ),
                ),
              ],
            ),
            
            // Spacer
            const SizedBox(height: 16),
            
            // Average value banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.trending_up,
                    color: Colors.teal,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Average Order Value:",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _salesStats['averageOrder'] > 0 
                      ? formatRupiah(_salesStats['averageOrder'])
                      : 'Rp 0',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Ultra compact stat widget with value emphasis
  Widget _buildCompactStat(Color color, String value, String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSalesChart() {
    // Generate sample dates for the past 7 days if no sales data available
    if (_salesData.isEmpty) {
      List<FlSpot> emptySpots = [];
      List<String> sampleDates = [];
      
      // Generate dates for the last 7 days
      final DateTime now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final formattedDate = DateFormat('yyyy-MM-dd').format(date);
        
        // Add zero sales data point
        emptySpots.add(FlSpot((6 - i).toDouble(), 0));
        // Add formatted date for display
        sampleDates.add(_formatChartDate(formattedDate));
      }
      
      return Container(
        height: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.getShadow(opacity: 0.1),
        ),
        child: Column(
          children: [
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 500,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: AppTheme.dividerColor.withOpacity(0.2),
                        strokeWidth: 0.5,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= sampleDates.length) {
                            return const SizedBox();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: Text(
                              sampleDates[index],
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondaryColor.withOpacity(0.7),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 500,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0) {
                            return const SizedBox();
                          }
                          return Text(
                            formatRupiah(value),
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondaryColor.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.right,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  minX: 0,
                  maxX: 6,
                  minY: 0,
                  maxY: 1000,
                  lineBarsData: [
                    LineChartBarData(
                      spots: emptySpots,
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: AppTheme.primaryColor,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.15),
                            AppTheme.primaryColor.withOpacity(0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No sales data available',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }
    
    // Code for when data is available
    final double maxAmount = _salesData.fold(0.0, (max, data) => 
      data['amount'] > max ? data['amount'] : max);
    
    // Make max y-axis value a nice round number
    final double roundedMaxY = (maxAmount == 0) ? 1000 : 
        ((maxAmount / 1000).ceil() * 1000).toDouble();
    final double yInterval = roundedMaxY / 4;
      
    // Prepare data for the chart
    final List<FlSpot> spots = [];
    final List<String> dates = [];
    
    for (int i = 0; i < _salesData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _salesData[i]['amount'].toDouble()));
      dates.add(_formatChartDate(_salesData[i]['date']));
    }
    
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getShadow(opacity: 0.1),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.dividerColor.withOpacity(0.2),
                strokeWidth: 0.5,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= dates.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 5.0),
                    child: Text(
                      dates[index],
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondaryColor.withOpacity(0.7),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: yInterval,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SizedBox();
                  }
                  return Text(
                    formatRupiah(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondaryColor.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: roundedMaxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppTheme.primaryColor.withOpacity(0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  return LineTooltipItem(
                    formatRupiah(touchedSpot.y),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppTheme.primaryColor,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.15),
                    AppTheme.primaryColor.withOpacity(0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatChartDate(String dateString) {
    final parsedDate = DateTime.parse(dateString);
    return DateFormat('dd MMM').format(parsedDate);
  }
  
  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.getShadow(opacity: 0.1),
        ),
        child: Center(
          child: Text(
            'No product sales data available',
            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getShadow(opacity: 0.1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topProducts.length,
        separatorBuilder: (context, index) => Divider(
          color: AppTheme.dividerColor.withOpacity(0.5),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final product = _topProducts[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: AppTheme.bodyMedium(color: AppTheme.primaryColor),
              ),
            ),
            title: Text(
              product['name'],
              style: AppTheme.bodyLarge(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Sold: ${product['count']} items',
              style: AppTheme.bodySmall(),
            ),
            trailing: Text(
              formatRupiah(product['revenue']),
              style: AppTheme.bodyLarge(color: AppTheme.successColor),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildLatestTransactions() {
    if (_latestTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.getShadow(opacity: 0.1),
        ),
        child: Center(
          child: Text(
            'No transactions available',
            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
          ),
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getShadow(opacity: 0.1),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _latestTransactions.length,
        separatorBuilder: (context, index) => Divider(
          color: AppTheme.dividerColor.withOpacity(0.5),
          height: 1,
        ),
        itemBuilder: (context, index) {
          final transaction = _latestTransactions[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(transaction.status).withOpacity(0.1),
              child: Icon(
                _getStatusIcon(transaction.status),
                color: _getStatusColor(transaction.status),
                size: 20,
              ),
            ),
            title: Text(
              'Order #${transaction.id.substring(0, 6)}',
              style: AppTheme.bodyLarge(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Customer: ${transaction.customerName} • ${_formatDate(transaction.createdAt)}',
              style: AppTheme.bodySmall(),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(transaction.totalAmount),
                  style: AppTheme.bodyLarge(color: AppTheme.successColor),
                ),
                Text(
                  _capitalizeStatus(transaction.status),
                  style: AppTheme.bodySmall(
                    color: _getStatusColor(transaction.status),
                  ),
                ),
              ],
            ),
            onTap: () {
              // TODO: Navigate to order details
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Order details coming soon!'),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'pending':
        return Colors.orange;
      case 'preparing':
        return AppTheme.primaryColor;
      case 'ready':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return AppTheme.textSecondaryColor;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'pending':
        return Icons.pending;
      case 'preparing':
        return Icons.restaurant;
      case 'ready':
        return Icons.delivery_dining;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt;
    }
  }
  
  String _formatDate(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }
  
  String _capitalizeStatus(String status) {
    return status.substring(0, 1).toUpperCase() + status.substring(1);
  }
  
  // Add this new method for building star ratings
  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // Full star
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index == rating.floor() && rating % 1 > 0) {
          // Half star
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.amber.withOpacity(0.7), size: 18);
        }
      }),
    );
  }
} 