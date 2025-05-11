import 'package:flutter/material.dart';
import '../../models/merchant_model.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../routes.dart';

class MerchantSettingsScreen extends StatefulWidget {
  final bool redirectedForSetup;
  final bool showScaffold;
  
  const MerchantSettingsScreen({
    Key? key, 
    this.redirectedForSetup = false,
    this.showScaffold = false,
  }) : super(key: key);

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storeDescriptionController = TextEditingController();
  final TextEditingController _storeAddressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';
  bool _hasRequiredFields = false;
  String _userEmail = '';
  
  // Cache for merchant data
  static MerchantModel? _cachedMerchantModel;
  
  @override
  void initState() {
    super.initState();
    // Apply cached data immediately if available
    if (_cachedMerchantModel != null) {
      _applyMerchantData(_cachedMerchantModel!);
      // Set loading to false immediately if we have cached data
      _isLoading = false;
    }
    // Always load fresh data in background
    _loadMerchantData();
  }
  
  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storeAddressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  // Apply merchant data to the UI
  void _applyMerchantData(MerchantModel merchantModel) {
    _storeNameController.text = merchantModel.storeName ?? '';
    _storeDescriptionController.text = merchantModel.storeDescription ?? '';
    _storeAddressController.text = merchantModel.storeAddress ?? '';
    _phoneController.text = merchantModel.phoneNumber;
    
    // Check if the merchant has the required fields
    _hasRequiredFields = merchantModel.isStoreConfigured();
    
    // Get current user email
    _userEmail = _authService.currentUser?.email ?? '';
  }
  
  Future<void> _loadMerchantData() async {
    try {
      final merchantModel = await _authService.getCurrentMerchantModel();
      
      if (merchantModel != null) {
        // Update cache
        _cachedMerchantModel = merchantModel;
        
        if (mounted) {
          setState(() {
            _applyMerchantData(merchantModel);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading merchant data: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });
    
    try {
      final success = await _authService.updateMerchantStore(
        storeName: _storeNameController.text.trim(),
        storeDescription: _storeDescriptionController.text.trim(),
        storeAddress: _storeAddressController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      
      if (success) {
        // Update cached model with new values
        if (_cachedMerchantModel != null) {
          _cachedMerchantModel = _cachedMerchantModel!.copyWith(
            storeName: _storeNameController.text.trim(),
            storeDescription: _storeDescriptionController.text.trim(),
            storeAddress: _storeAddressController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
          );
        }
        
        if (mounted) {
          setState(() {
            _hasRequiredFields = true;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Store settings saved successfully'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          // If we were redirected to complete setup, go back to merchant home
          if (widget.redirectedForSetup) {
            Navigator.pushReplacementNamed(context, AppRoutes.merchant);
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to save store settings';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving store settings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('This feature will be available soon.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.signOut();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.showScaffold
        ? Scaffold(
            appBar: AppBar(
              title: const Text(
                'Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppTheme.primaryColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (widget.redirectedForSetup && !_hasRequiredFields) {
                    // Show dialog warning that setup must be completed
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Required Setup'),
                        content: const Text(
                          'You need to complete the store setup before continuing. Please provide your store name and phone number.',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Navigate back to merchant home screen
                    Navigator.pushReplacementNamed(context, AppRoutes.merchant);
                  }
                },
              ),
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with user profile
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                            child: Column(
                              children: [
                                // User avatar and info
                                Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
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
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _storeNameController.text.isNotEmpty 
                                              ? _storeNameController.text[0].toUpperCase()
                                              : 'M',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _storeNameController.text.isNotEmpty 
                                                ? _storeNameController.text 
                                                : 'Your Store',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _userEmail,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.white.withOpacity(0.9),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Setup reminder if needed
                        if (widget.redirectedForSetup)
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(color: Colors.amber.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.amber.shade700, size: 28),
                                    const SizedBox(width: 12.0),
                                    const Expanded(
                                      child: Text(
                                        'Complete your store setup',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18.0,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12.0),
                                const Text(
                                  'You need to set up your store information before you can start selling. Please provide your store name and phone number.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Main content with settings cards
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Account Settings Card
                              _buildSettingsCard(
                                title: 'Account Settings',
                                icon: Icons.person,
                                iconColor: Colors.blue,
                                children: [
                                  _buildSettingsTile(
                                    title: 'Change Password',
                                    icon: Icons.lock_outline,
                                    onTap: _showChangePasswordDialog,
                                  ),
                                  _buildSettingsTile(
                                    title: 'Logout',
                                    icon: Icons.logout,
                                    iconColor: Colors.red,
                                    onTap: _showLogoutConfirmation,
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Store Information Card
                              _buildSettingsCard(
                                title: 'Store Information',
                                icon: Icons.store,
                                iconColor: Colors.green,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          TextFormField(
                                            controller: _storeNameController,
                                            decoration: InputDecoration(
                                              labelText: 'Store Name *',
                                              hintText: 'Enter your store name',
                                              labelStyle: TextStyle(color: Colors.grey.shade700),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              contentPadding: const EdgeInsets.all(16),
                                              prefixIcon: const Icon(Icons.store, color: Colors.green),
                                            ),
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your store name';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 20.0),
                                          
                                          TextFormField(
                                            controller: _storeDescriptionController,
                                            decoration: InputDecoration(
                                              labelText: 'Store Description',
                                              hintText: 'Describe your store to customers',
                                              labelStyle: TextStyle(color: Colors.grey.shade700),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              contentPadding: const EdgeInsets.all(16),
                                              prefixIcon: const Icon(Icons.description, color: Colors.green),
                                            ),
                                            maxLines: 3,
                                          ),
                                          const SizedBox(height: 20.0),
                                          
                                          TextFormField(
                                            controller: _storeAddressController,
                                            decoration: InputDecoration(
                                              labelText: 'Store Address',
                                              hintText: 'Enter your store address',
                                              labelStyle: TextStyle(color: Colors.grey.shade700),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              contentPadding: const EdgeInsets.all(16),
                                              prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                                            ),
                                          ),
                                          const SizedBox(height: 20.0),
                                          
                                          TextFormField(
                                            controller: _phoneController,
                                            decoration: InputDecoration(
                                              labelText: 'Phone Number *',
                                              hintText: 'Enter your phone number',
                                              labelStyle: TextStyle(color: Colors.grey.shade700),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: Colors.grey.shade300),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(12.0),
                                                borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey.shade50,
                                              contentPadding: const EdgeInsets.all(16),
                                              prefixIcon: const Icon(Icons.phone, color: Colors.green),
                                            ),
                                            keyboardType: TextInputType.phone,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your phone number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Notifications Settings Card
                              _buildSettingsCard(
                                title: 'Notifications',
                                icon: Icons.notifications,
                                iconColor: Colors.orange,
                                children: [
                                  _buildSettingsTile(
                                    title: 'Push Notifications',
                                    subtitle: 'Coming soon',
                                    icon: Icons.notifications_active,
                                    trailing: Switch(
                                      value: false,
                                      onChanged: (value) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('This feature is coming soon'),
                                          ),
                                        );
                                      },
                                      activeColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                  _buildSettingsTile(
                                    title: 'Email Notifications',
                                    subtitle: 'Coming soon',
                                    icon: Icons.email,
                                    trailing: Switch(
                                      value: false,
                                      onChanged: (value) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('This feature is coming soon'),
                                          ),
                                        );
                                      },
                                      activeColor: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Error message if any
                              if (_errorMessage.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16.0),
                                  margin: const EdgeInsets.only(bottom: 24.0),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(color: Colors.red.shade300),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade700),
                                      const SizedBox(width: 12.0),
                                      Expanded(
                                        child: Text(
                                          _errorMessage,
                                          style: TextStyle(color: Colors.red.shade700),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              // Save button
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isSaving
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.0,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Text(
                                              'Saving...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.save),
                                            SizedBox(width: 12),
                                            Text(
                                              'Save Settings',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // App Info
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'EatEase v1.0.0',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          )
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user profile
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
                    child: Column(
                      children: [
                        // User avatar and info
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
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
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _storeNameController.text.isNotEmpty 
                                      ? _storeNameController.text[0].toUpperCase()
                                      : 'M',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _storeNameController.text.isNotEmpty 
                                        ? _storeNameController.text 
                                        : 'Your Store',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _userEmail,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Setup reminder if needed
                if (widget.redirectedForSetup)
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.amber.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade700, size: 28),
                            const SizedBox(width: 12.0),
                            const Expanded(
                              child: Text(
                                'Complete your store setup',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18.0,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
                        const Text(
                          'You need to set up your store information before you can start selling. Please provide your store name and phone number.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Main content with settings cards
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Settings Card
                      _buildSettingsCard(
                        title: 'Account Settings',
                        icon: Icons.person,
                        iconColor: Colors.blue,
                        children: [
                          _buildSettingsTile(
                            title: 'Change Password',
                            icon: Icons.lock_outline,
                            onTap: _showChangePasswordDialog,
                          ),
                          _buildSettingsTile(
                            title: 'Logout',
                            icon: Icons.logout,
                            iconColor: Colors.red,
                            onTap: _showLogoutConfirmation,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Store Information Card
                      _buildSettingsCard(
                        title: 'Store Information',
                        icon: Icons.store,
                        iconColor: Colors.green,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _storeNameController,
                                    decoration: InputDecoration(
                                      labelText: 'Store Name *',
                                      hintText: 'Enter your store name',
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(16),
                                      prefixIcon: const Icon(Icons.store, color: Colors.green),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your store name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20.0),
                                  
                                  TextFormField(
                                    controller: _storeDescriptionController,
                                    decoration: InputDecoration(
                                      labelText: 'Store Description',
                                      hintText: 'Describe your store to customers',
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(16),
                                      prefixIcon: const Icon(Icons.description, color: Colors.green),
                                    ),
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 20.0),
                                  
                                  TextFormField(
                                    controller: _storeAddressController,
                                    decoration: InputDecoration(
                                      labelText: 'Store Address',
                                      hintText: 'Enter your store address',
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(16),
                                      prefixIcon: const Icon(Icons.location_on, color: Colors.green),
                                    ),
                                  ),
                                  const SizedBox(height: 20.0),
                                  
                                  TextFormField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number *',
                                      hintText: 'Enter your phone number',
                                      labelStyle: TextStyle(color: Colors.grey.shade700),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.0),
                                        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                      contentPadding: const EdgeInsets.all(16),
                                      prefixIcon: const Icon(Icons.phone, color: Colors.green),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Notifications Settings Card
                      _buildSettingsCard(
                        title: 'Notifications',
                        icon: Icons.notifications,
                        iconColor: Colors.orange,
                        children: [
                          _buildSettingsTile(
                            title: 'Push Notifications',
                            subtitle: 'Coming soon',
                            icon: Icons.notifications_active,
                            trailing: Switch(
                              value: false,
                              onChanged: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('This feature is coming soon'),
                                  ),
                                );
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                          _buildSettingsTile(
                            title: 'Email Notifications',
                            subtitle: 'Coming soon',
                            icon: Icons.email,
                            trailing: Switch(
                              value: false,
                              onChanged: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('This feature is coming soon'),
                                  ),
                                );
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Error message if any
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16.0),
                          margin: const EdgeInsets.only(bottom: 24.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red.shade700),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 2,
                          ),
                          child: _isSaving
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Saving...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save),
                                    SizedBox(width: 12),
                                    Text(
                                      'Save Settings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // App Info
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'EatEase v1.0.0',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
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
  }
  
  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color iconColor = Colors.blue,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required IconData icon,
    Color iconColor = Colors.grey,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
} 