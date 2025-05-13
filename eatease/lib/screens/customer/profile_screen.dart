import 'package:flutter/material.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerProfileScreen extends StatefulWidget {
  final bool showScaffold;
  
  const CustomerProfileScreen({
    Key? key,
    this.showScaffold = true,
  }) : super(key: key);

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
  
  // Track button press states for neumorphic effect
  bool _saveButtonPressed = false;
  bool _signOutButtonPressed = false;
  
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

  // Custom neumorphic text field
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: AppTheme.getNeumorphismDecoration(
        color: AppTheme.neumorphismBackground,
        borderRadius: 16,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
        validator: validator,
        keyboardType: keyboardType,
      ),
    );
  }
  
  // Custom neumorphic button
  Widget _buildNeumorphicButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPressed,
    required Function(bool) onPressedChange,
    Color? textColor,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressedChange(true),
      onTapUp: (_) {
        onPressedChange(false);
        onPressed();
      },
      onTapCancel: () => onPressedChange(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: AppTheme.getNeumorphismDecoration(
          isPressed: isPressed,
          color: backgroundColor ?? AppTheme.neumorphismBackground,
          borderRadius: 16,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: textColor ?? AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: AppTheme.buttonText(
                  color: textColor ?? AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Custom neumorphic list tile
  Widget _buildNeumorphicListTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.getNeumorphismDecoration(
        color: AppTheme.neumorphismBackground,
        borderRadius: 16,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(
          title,
          style: AppTheme.bodyLarge(),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textSecondaryColor),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Center(
                  child: Column(
                    children: [
                      // Profile image with neumorphic container
                      Container(
                        width: 120,
                        height: 120,
                        decoration: AppTheme.getNeumorphismDecoration(
                          color: AppTheme.neumorphismBackground,
                          borderRadius: 60,
                        ),
                        child: Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.neumorphismBackground,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: _photoUrl != null && _photoUrl!.isNotEmpty
                                ? Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 60,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: AppTheme.textSecondaryColor,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _userName ?? 'User',
                        style: AppTheme.headingMedium(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _email ?? '',
                        style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Profile form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 20),
                        child: Text(
                          'Edit Profile',
                          style: AppTheme.headingSmall(),
                        ),
                      ),
                      
                      // Display name field
                      _buildNeumorphicTextField(
                        controller: _displayNameController,
                        label: 'Display Name',
                        icon: Icons.person,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      
                      // Phone number field
                      _buildNeumorphicTextField(
                        controller: _phoneNumberController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Save button
                      _isSaving
                        ? Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: AppTheme.getNeumorphismDecoration(
                                color: AppTheme.neumorphismBackground,
                                borderRadius: 28,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          )
                        : _buildNeumorphicButton(
                            text: 'Save Changes',
                            onPressed: _updateProfile,
                            isPressed: _saveButtonPressed,
                            onPressedChange: (value) => setState(() => _saveButtonPressed = value),
                            textColor: Colors.white,
                            backgroundColor: AppTheme.primaryColor,
                          ),
                      
                      const SizedBox(height: 40),
                      
                      // Settings Options
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 20),
                        child: Text(
                          'Settings',
                          style: AppTheme.headingSmall(),
                        ),
                      ),
                      
                      // Neumorphic list tiles
                      _buildNeumorphicListTile(
                        title: 'Notifications',
                        icon: Icons.notifications_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notifications coming soon!')),
                          );
                        },
                      ),
                      
                      _buildNeumorphicListTile(
                        title: 'Language',
                        icon: Icons.language_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Language settings coming soon!')),
                          );
                        },
                      ),
                      
                      _buildNeumorphicListTile(
                        title: 'Privacy & Security',
                        icon: Icons.lock_outline,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Privacy settings coming soon!')),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Sign out button
                      _buildNeumorphicButton(
                        text: 'Sign Out',
                        onPressed: _signOut,
                        isPressed: _signOutButtonPressed,
                        onPressedChange: (value) => setState(() => _signOutButtonPressed = value),
                        textColor: Colors.red.shade700,
                        icon: Icons.logout,
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
    
    if (!widget.showScaffold) {
      return content;
    }
    
    return Scaffold(
      backgroundColor: AppTheme.neumorphismBackground,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      body: content,
      bottomNavigationBar: FutureBuilder<String>(
        future: _authService.getUserRole(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          
          final userRole = snapshot.data ?? 'customer';
          return BottomNavBar(
            currentIndex: 4, // Profile tab is now at index 4
            userRole: userRole,
          );
        },
      ),
    );
  }
} 