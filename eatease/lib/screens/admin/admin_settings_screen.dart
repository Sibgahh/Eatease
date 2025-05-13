import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth/auth_service.dart';
import '../../models/user_model.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Active role is the currently displayed UI role
  String _activeRole = 'admin';
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          setState(() {
            _currentUser = UserModel.fromMap(doc.data()!, doc.id);
            _activeRole = _currentUser!.role;
          });
        }
      }
    } catch (e) {
      print('Error loading user: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchRole(String newRole) async {
    if (_currentUser == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // If it's already in the roles array, just update the active role
      List<String> roles = _currentUser!.roles?.toList() ?? [_currentUser!.role];
      
      // Make sure 'admin' is always in the roles array
      if (!roles.contains('admin')) {
        roles.add('admin');
      }
      
      // Add the new role if it's not already there
      if (!roles.contains(newRole)) {
        roles.add(newRole);
      }
      
      // Update in Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'role': newRole,
        'roles': roles,
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $newRole view'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload current user
      await _loadCurrentUser();
      
      // Navigate back to main page based on new role
      if (mounted) {
        if (newRole == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      print('Error switching role: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching role: $e'),
            backgroundColor: Colors.red,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile Section
                const Text(
                  'Admin Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_currentUser != null) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade200,
                      child: Text(
                        _currentUser!.displayName.isNotEmpty
                            ? _currentUser!.displayName[0].toUpperCase()
                            : 'A',
                      ),
                    ),
                    title: Text(_currentUser!.displayName),
                    subtitle: Text(_currentUser!.email),
                  ),
                  
                  const Divider(),
                  
                  // Role Switching Section
                  const Text(
                    'Experience Modes',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Switch between different user roles to experience the app from different perspectives',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Admin Role Card
                  _buildRoleCard(
                    'Admin',
                    'Manage users, content, and all app settings',
                    Icons.admin_panel_settings,
                    Colors.red,
                    _activeRole == 'admin',
                    () => _switchRole('admin'),
                  ),
                  
                  // Merchant Role Card
                  _buildRoleCard(
                    'Merchant',
                    'Experience the app as a merchant user',
                    Icons.store,
                    Colors.blue,
                    _activeRole == 'merchant',
                    () => _switchRole('merchant'),
                  ),
                  
                  // Customer Role Card
                  _buildRoleCard(
                    'Customer',
                    'Experience the app as a customer user',
                    Icons.person,
                    Colors.green,
                    _activeRole == 'customer',
                    () => _switchRole('customer'),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'Note: When you switch roles, you\'ll maintain admin privileges and can always switch back.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildRoleCard(
    String title,
    String description,
    IconData icon,
    Color color,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isActive
            ? BorderSide(color: color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: color, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: TextStyle(
                          color: color,
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
    );
  }
} 