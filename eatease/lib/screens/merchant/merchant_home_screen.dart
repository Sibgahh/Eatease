import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/auth/auth_service.dart';
import '../../services/sales_service.dart';
import '../../models/merchant_model.dart';
import '../../utils/app_theme.dart';
import 'product_list_screen.dart';
import 'merchant_settings_screen.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../routes.dart';

class MerchantHomeScreen extends StatefulWidget {
  const MerchantHomeScreen({super.key});

  @override
  State<MerchantHomeScreen> createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  final AuthService _authService = AuthService();
  final SalesService _salesService = SalesService();
  bool _isLoading = true;
  bool _isStoreConfigured = false;
  String _merchantName = 'Merchant';
  
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
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load merchant data
      final merchantModel = await _authService.getCurrentMerchantModel();
      
      if (merchantModel != null) {
        setState(() {
          _isStoreConfigured = merchantModel.isStoreConfigured();
          _merchantName = merchantModel.displayName;
        });
        
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
      }
      
      // Load sales statistics
      final salesStats = await _salesService.getMerchantSalesStats();
      final salesData = await _salesService.getMerchantSalesSummaryByDay();
      final topProducts = await _salesService.getTopSellingProducts();
      
      if (mounted) {
        setState(() {
          _salesStats = salesStats;
          _salesData = salesData;
          _topProducts = topProducts;
        });
      }
    } catch (e) {
      print('Error loading merchant dashboard data: $e');
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'EatEase Merchant',
            style: AppTheme.headingSmall(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EatEase Merchant',
          style: AppTheme.headingSmall(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 2,
        actions: [
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
                  Navigator.pushNamed(context, '/admin');
                },
                tooltip: 'Admin Dashboard',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryColor, AppTheme.primaryColor.withOpacity(0.8)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: AppTheme.getShadow(),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $_merchantName!',
                      style: AppTheme.headingLarge(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Manage your restaurant and track performance',
                      style: AppTheme.bodyMedium(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store setup reminder (if not configured)
                    if (!_isStoreConfigured)
                      _buildSetupReminder(),
                      
                    // Today's Stats Cards
                    const SizedBox(height: 16),
                    Text('Today\'s Performance', style: AppTheme.headingMedium()),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Today\'s Sales',
                            '\$${_salesStats['todaySales'].toStringAsFixed(2)}',
                            Icons.attach_money,
                            AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Today\'s Orders',
                            _salesStats['todayOrders'].toString(),
                            Icons.shopping_bag,
                            AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                    
                    // Overall Performance Stats
                    const SizedBox(height: 24),
                    Text('Overall Performance', style: AppTheme.headingMedium()),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Sales',
                            '\$${_salesStats['totalSales'].toStringAsFixed(2)}',
                            Icons.payments,
                            AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Orders',
                            _salesStats['totalOrders'].toString(),
                            Icons.receipt_long,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    _buildStatCard(
                      'Average Order Value',
                      '\$${_salesStats['averageOrder'].toStringAsFixed(2)}',
                      Icons.trending_up,
                      Colors.teal,
                    ),
                    
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
                    
                    // Quick Actions
                    const SizedBox(height: 24),
                    Text('Quick Actions', style: AppTheme.headingMedium()),
                    const SizedBox(height: 12),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'merchant';
          return BottomNavBar(
            currentIndex: 0,  // Home tab
            userRole: userRole,
          );
        },
      ),
    );
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
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.getShadow(opacity: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTheme.headingMedium(color: color),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSalesChart() {
    if (_salesData.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.getShadow(opacity: 0.1),
        ),
        child: Center(
          child: Text(
            'No sales data available',
            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
          ),
        ),
      );
    }
    
    final double maxAmount = _salesData.fold(0.0, (max, data) => 
      data['amount'] > max ? data['amount'] : max);
      
    // Prepare data for the chart
    final List<FlSpot> spots = [];
    final List<String> dates = [];
    
    for (int i = 0; i < _salesData.length; i++) {
      spots.add(FlSpot(i.toDouble(), _salesData[i]['amount'].toDouble()));
      dates.add(_formatChartDate(_salesData[i]['date']));
    }
    
    return Container(
      height: 300,
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
            drawVerticalLine: true,
            horizontalInterval: maxAmount / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: AppTheme.dividerColor.withOpacity(0.3),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: AppTheme.dividerColor.withOpacity(0.3),
                strokeWidth: 1,
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
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final int index = value.toInt();
                  if (index < 0 || index >= dates.length) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dates[index],
                      style: AppTheme.bodySmall(),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: maxAmount / 5,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toInt()}',
                    style: AppTheme.bodySmall(),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: AppTheme.dividerColor.withOpacity(0.5),
            ),
          ),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: 0,
          maxY: maxAmount * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatChartDate(String dateString) {
    final parsedDate = DateTime.parse(dateString);
    return DateFormat('MM/dd').format(parsedDate);
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
              '\$${product['revenue'].toStringAsFixed(2)}',
              style: AppTheme.bodyLarge(color: AppTheme.successColor),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Products Card
        _buildActionCard(
          context,
          'Manage Products',
          Icons.restaurant_menu,
          AppTheme.accentColor,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductListScreen(),
              ),
            );
          },
        ),
        
        // Orders Card
        _buildActionCard(
          context,
          'View Orders',
          Icons.receipt_long,
          AppTheme.successColor,
          () {
            // TODO: Navigate to orders screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Orders feature coming soon!'),
              ),
            );
          },
        ),
        
        // Settings Card
        _buildActionCard(
          context,
          'Store Settings',
          Icons.settings,
          Colors.purple,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MerchantSettingsScreen(),
              ),
            );
          },
        ),
        
        // Analytics Card
        _buildActionCard(
          context,
          'Detailed Analytics',
          Icons.bar_chart,
          Colors.teal,
          () {
            // TODO: Navigate to analytics screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Detailed analytics coming soon!'),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: AppTheme.getShadow(opacity: 0.1),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTheme.bodyLarge(color: AppTheme.textPrimaryColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 