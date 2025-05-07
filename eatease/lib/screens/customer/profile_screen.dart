import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userName;
  String? _email;
  String? _phoneNumber;
  String? _photoUrl;
  
  @override
  void initState() {
    super.initState();
    print('[PROFILE] Initializing profile screen');
    _loadUserData();
    
    // Add a delay to verify the route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      print('[PROFILE] Current route: $currentRoute');
    });
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get the current user's data
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
            
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _userName = userData['displayName'] as String? ?? user.displayName;
            _email = userData['email'] as String? ?? user.email;
            _phoneNumber = userData['phoneNumber'] as String? ?? '';
            _photoUrl = userData['photoURL'] as String? ?? user.photoURL;
            
            _displayNameController.text = _userName ?? '';
            _phoneNumberController.text = _phoneNumber ?? '';
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Update in Firebase Authentication
        await user.updateDisplayName(_displayNameController.text.trim());
        
        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'displayName': _displayNameController.text.trim(),
              'phoneNumber': _phoneNumberController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            
        setState(() {
          _userName = _displayNameController.text.trim();
          _phoneNumber = _phoneNumberController.text.trim();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Profile image
                        Container(
                          width: 100,
                          height: 100,
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
                          child: _photoUrl != null && _photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userName ?? 'User',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Profile form
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Display name field
                          TextFormField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Phone number field
                          TextFormField(
                            controller: _phoneNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 24),
                          
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Save Changes'),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                          // Additional options
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.notifications_outlined),
                                  title: const Text('Notifications'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Notifications coming soon!')),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.language_outlined),
                                  title: const Text('Language'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Language settings coming soon!')),
                                    );
                                  },
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.lock_outline),
                                  title: const Text('Privacy & Security'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Privacy settings coming soon!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Sign out button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              onPressed: _signOut,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.red.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Sign Out',
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'customer';
          return BottomNavBar(
            currentIndex: 3, // Profile tab
            userRole: userRole,
          );
        },
      ),
    );
  }
} 