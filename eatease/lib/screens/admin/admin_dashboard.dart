import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/auth_service.dart';
import 'user_management_screen.dart';
import '../../widgets/bottom_nav_bar.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  int _customerCount = 0;
  int _merchantCount = 0;
  int _adminCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print("AdminDashboard initState called");
    _loadUserCounts();
  }

  Future<void> _loadUserCounts() async {
    print("Loading user counts...");
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Count customers
      print("Counting customers...");
      final customerQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'customer')
          .count()
          .get();
      
      // Count merchants
      print("Counting merchants...");
      final merchantQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'merchant')
          .count()
          .get();
      
      // Count admins
      print("Counting admins...");
      final adminQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .count()
          .get();

      print("Customer count: ${customerQuery.count}, Merchant count: ${merchantQuery.count}, Admin count: ${adminQuery.count}");
      setState(() {
        _customerCount = customerQuery.count ?? 0;
        _merchantCount = merchantQuery.count ?? 0;
        _adminCount = adminQuery.count ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user counts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Building AdminDashboard");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              print("Opening admin settings");
              Navigator.pushNamed(context, '/admin/settings');
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserCounts,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              print("Admin logout pressed");
              await _authService.signOut();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome, Super Admin',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // User Statistics Cards
                  const Text(
                    'User Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
                        'Customers',
                        _customerCount,
                        Colors.blue.shade100,
                        Colors.blue,
                        Icons.people,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Merchants',
                        _merchantCount,
                        Colors.green.shade100,
                        Colors.green,
                        Icons.store,
                      ),
                      const SizedBox(width: 16),
                      _buildStatCard(
                        'Admins',
                        _adminCount,
                        Colors.red.shade100,
                        Colors.red,
                        Icons.admin_panel_settings,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Admin Actions
                  const Text(
                    'Admin Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildActionCard(
                    'User Management',
                    'Add, edit, and manage user accounts',
                    Icons.people_alt,
                    Colors.blue.shade600,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Additional action cards can be added here for other admin functions
                ],
              ),
            ),
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'admin';
          return BottomNavBar(
            currentIndex: 0,
            userRole: userRole,
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color bgColor, Color textColor, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: textColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String description, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
} 