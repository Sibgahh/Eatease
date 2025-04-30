import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../utils/string_extensions.dart';
import 'add_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  String _selectedRole = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
      ),
      body: Column(
        children: [
          _buildRoleFilter(),
          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'admin';
          return BottomNavBar(
            currentIndex: 1, // Users section is selected
            userRole: userRole,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddUserScreen()),
          );
        },
        backgroundColor: Colors.green.shade600,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildRoleFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text('Filter by role: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedRole,
            onChanged: (String? newValue) {
              setState(() {
                _selectedRole = newValue!;
              });
            },
            items: <String>['all', 'admin', 'merchant', 'customer', 'user']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.charAt(0).toUpperCase() + value.substring(1)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    Query query = _firestore.collection('users');
    
    if (_selectedRole != 'all') {
      query = query.where('role', isEqualTo: _selectedRole);
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No users found'));
        }
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            final bool isAdmin = user.role == 'admin';
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade200,
                  child: Text(
                    user.displayName.isNotEmpty ? 
                      user.displayName[0].toUpperCase() : 
                      '?'
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(user.displayName)),
                    if (!user.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'BANNED',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.email),
                    Text('Phone: ${user.phoneNumber}'),
                    Text('Role: ${user.role}', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getRoleColor(user.role),
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Edit user implementation
                      },
                      tooltip: 'Edit user',
                    ),
                    IconButton(
                      icon: Icon(
                        user.isActive ? Icons.block : Icons.check_circle,
                        color: user.isActive ? Colors.red : Colors.green,
                      ),
                      onPressed: isAdmin ? null : () {
                        _showBanConfirmationDialog(user);
                      },
                      tooltip: user.isActive ? 'Ban user' : 'Unban user',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBanConfirmationDialog(UserModel user) async {
    final bool isBanning = user.isActive;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isBanning ? 'Ban User' : 'Unban User'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(isBanning 
                  ? 'Are you sure you want to ban ${user.displayName}? They will no longer be able to access the application.'
                  : 'Are you sure you want to unban ${user.displayName}? This will restore their access to the application.'
                ),
                const SizedBox(height: 10),
                Text(
                  'Email: ${user.email}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Role: ${user.role.charAt(0).toUpperCase() + user.role.substring(1)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(user.role),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                isBanning ? 'Ban' : 'Unban',
                style: TextStyle(
                  color: isBanning ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _toggleUserStatus(user);
              },
            ),
          ],
        );
      },
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'merchant':
        return Colors.blue;
      case 'customer':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _toggleUserStatus(UserModel user) async {
    try {
      if (user.role == 'admin') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin accounts cannot be banned'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final bool newStatus = !user.isActive;
      
      await _firestore.collection('users').doc(user.id).update({
        'isActive': newStatus,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus 
              ? '${user.displayName} has been unbanned' 
              : '${user.displayName} has been banned'
          ),
          backgroundColor: newStatus ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating user status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 