import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import 'product_list_screen.dart';

class MerchantHomeScreen extends StatelessWidget {
  const MerchantHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print("MERCHANT HOME: Building MerchantHomeScreen");
    final AuthService authService = AuthService();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('EatEase - Merchant'),
        backgroundColor: Colors.blue.shade600,
        actions: [
          // Admin Panel Button (only visible to admins)
          FutureBuilder<bool>(
            future: authService.isAdmin(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || snapshot.data != true) {
                return const SizedBox();
              }
              
              return IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                onPressed: () {
                  print("MERCHANT HOME: Admin icon pressed, navigating to admin dashboard");
                  Navigator.pushNamed(context, '/admin');
                },
                tooltip: 'Admin Dashboard',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              print("MERCHANT HOME: Logout pressed");
              await authService.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome section
              const Text(
                'Welcome, Merchant!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your restaurant and orders',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              
              // Quick actions
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              
              GridView.count(
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
                    Colors.orange,
                    () {
                      print("MERCHANT HOME: Navigating to Product List Screen");
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
                    Colors.green,
                    () {
                      // TODO: Navigate to orders screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Orders feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  
                  // Analytics Card
                  _buildActionCard(
                    context,
                    'Analytics',
                    Icons.bar_chart,
                    Colors.purple,
                    () {
                      // TODO: Navigate to analytics screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analytics feature coming soon!'),
                        ),
                      );
                    },
                  ),
                  
                  // Settings Card
                  _buildActionCard(
                    context,
                    'Settings',
                    Icons.settings,
                    Colors.blue,
                    () {
                      // TODO: Navigate to settings screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settings feature coming soon!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Admin Mode Indicator (only visible to admins)
              FutureBuilder<bool>(
                future: authService.isAdmin(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox();
                  }
                  
                  if (snapshot.data == true) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Admin Mode',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'You are viewing the app as a merchant.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pushNamed(context, '/admin');
                            },
                            icon: const Icon(Icons.admin_panel_settings),
                            label: const Text('Return to Admin Dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
      // Admin Quick Access Button
      floatingActionButton: FutureBuilder<bool>(
        future: authService.isAdmin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          if (snapshot.data == true) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/admin');
              },
              backgroundColor: Colors.red,
              child: const Icon(Icons.admin_panel_settings),
              tooltip: 'Back to Admin Dashboard',
            );
          }
          
          return const SizedBox();
        },
      ),
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
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 