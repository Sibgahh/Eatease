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
  
  // Track button press states for neumorphic effect
  bool _saveButtonPressed = false;
  bool _logoutButtonPressed = false;
  bool _changePasswordPressed = false;
  
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
      _saveButtonPressed = true;
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
            _saveButtonPressed = false;
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
          _saveButtonPressed = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving store settings: $e';
        _saveButtonPressed = false;
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
              backgroundColor: AppTheme.merchantPrimaryColor,
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
            backgroundColor: AppTheme.neumorphismBackground,
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          )
        : _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody();
  }

  Widget _buildBody() {
    return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
          // Header with user profile - unique design
          _buildUniqueHeader(),
                        
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
                        
          // Main content with settings sections
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                // Account Settings Section
                Form(
                  key: _formKey,
                  child: _buildNeumorphicSection(
                                title: 'Store Information',
                                icon: Icons.store,
                                children: [
                      _buildNeumorphicTextField(
                                            controller: _storeNameController,
                        label: 'Store Name',
                        icon: Icons.store,
                                              hintText: 'Enter your store name',
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your store name';
                                              }
                                              return null;
                                            },
                        isRequired: true,
                                          ),
                                          
                      _buildNeumorphicTextField(
                                            controller: _storeDescriptionController,
                        label: 'Store Description',
                        icon: Icons.description,
                                              hintText: 'Describe your store to customers',
                                            maxLines: 3,
                                          ),
                                          
                      _buildNeumorphicTextField(
                                            controller: _storeAddressController,
                        label: 'Store Address',
                        icon: Icons.location_on,
                                              hintText: 'Enter your store address',
                      ),
                      
                      _buildNeumorphicTextField(
                                            controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone,
                                              hintText: 'Enter your phone number',
                                            keyboardType: TextInputType.phone,
                                            validator: (value) {
                                              if (value == null || value.isEmpty) {
                                                return 'Please enter your phone number';
                                              }
                                              return null;
                                            },
                        isRequired: true,
                                          ),
                                        ],
                                      ),
                ),
                              
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
                _buildNeumorphicButton(
                  text: _isSaving ? 'Saving...' : 'Save Settings',
                                  onPressed: _isSaving ? null : _saveSettings,
                  isPressed: _saveButtonPressed,
                  onPressedChange: (value) => setState(() => _saveButtonPressed = value),
                  backgroundColor: AppTheme.merchantPrimaryColor,
                  textColor: Colors.white,
                  icon: Icons.save,
                              ),
                              
                              const SizedBox(height: 24),

                            _buildNeumorphicSection(
                                title: 'Account Settings',
                                icon: Icons.person,
                                children: [
                    _buildSettingOption(
                                    icon: Icons.lock_outline,
                      title: 'Change Password',
                      onTap: () {
                        setState(() => _changePasswordPressed = true);
                        Future.delayed(const Duration(milliseconds: 150), () {
                          setState(() => _changePasswordPressed = false);
                          _showChangePasswordDialog();
                        });
                      },
                      isPressed: _changePasswordPressed,
                    ),
                    const SizedBox(height: 16),
                    _buildSettingOption(
                                    icon: Icons.logout,
                      title: 'Logout',
                      textColor: Colors.red.shade700,
                      iconColor: Colors.red.shade700,
                      onTap: () {
                        setState(() => _logoutButtonPressed = true);
                        Future.delayed(const Duration(milliseconds: 150), () {
                          setState(() => _logoutButtonPressed = false);
                          _showLogoutConfirmation();
                        });
                      },
                      isPressed: _logoutButtonPressed,
                                  ),
                                ],
                              ),
                              
                // Store Information Section
                
                            ],
                          ),
                        ),
                                                      
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
    );
  }
  
  // Unique header design with neumorphic elements
  Widget _buildUniqueHeader() {
    final storeName = _storeNameController.text.isNotEmpty 
        ? _storeNameController.text 
        : 'Your Store';
    final storeInitial = storeName.isNotEmpty ? storeName[0].toUpperCase() : 'M';
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.merchantPrimaryColor.withOpacity(0.8),
            AppTheme.merchantPrimaryColor,
          ],
        ),
      ),
            child: Column(
              children: [
          const SizedBox(height: 20),
          // Store logo and name card
                Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
              color: AppTheme.neumorphismBackground,
              borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
            child: Row(
                      children: [
                // Store logo/avatar with neumorphic design
                            Container(
                              width: 80,
                              height: 80,
                  decoration: AppTheme.getNeumorphismDecoration(
                    borderRadius: 40,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.merchantPrimaryColor.withOpacity(0.7),
                            AppTheme.merchantPrimaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                              ),
                              child: Center(
                                child: Text(
                          storeInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                      // Store name with subtle neumorphic effect
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: AppTheme.getNeumorphismDecoration(
                          borderRadius: 12,
                          isPressed: true,
                        ),
                        child: Text(
                          storeName,
                          style: TextStyle(
                            fontSize: 20,
                                      fontWeight: FontWeight.bold,
                            color: AppTheme.merchantPrimaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                      ),
                      const SizedBox(height: 10),
                      // Email with subtle design
                  Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                      children: [
                            Icon(
                              Icons.email_outlined,
                              size: 16,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _userEmail,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          ),
                        ),
                      ],
                    ),
                ),
              ],
            ),
          ),
          
          // Curved bottom design
          Container(
            height: 30,
            margin: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              color: AppTheme.neumorphismBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Custom setting option widget for neumorphic design
  Widget _buildSettingOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isPressed,
    String? subtitle,
    Color? iconColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          // This is handled by the passed isPressed parameter
        });
      },
      onTapUp: (_) {
        onTap();
      },
      onTapCancel: () {
        setState(() {
          // This is handled by the passed isPressed parameter
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.neumorphismBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPressed 
                ? AppTheme.merchantPrimaryColor.withOpacity(0.3) 
                : AppTheme.neumorphismBackground,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: iconColor ?? AppTheme.merchantPrimaryColor,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                                ],
                              ),
                            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
                          ),
                        ],
                      ),
      ),
    );
  }
  
  // Custom neumorphic text field
  Widget _buildNeumorphicTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isRequired = false,
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
          labelText: isRequired ? '$label *' : label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: AppTheme.merchantPrimaryColor),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
        validator: validator,
        keyboardType: keyboardType,
        maxLines: maxLines,
      ),
    );
  }
  
  // Custom neumorphic button
  Widget _buildNeumorphicButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isPressed,
    required Function(bool) onPressedChange,
    Color? textColor,
    Color? backgroundColor,
    IconData? icon,
  }) {
    return GestureDetector(
      onTapDown: onPressed == null ? null : (_) => onPressedChange(true),
      onTapUp: onPressed == null ? null : (_) {
        onPressedChange(false);
        onPressed();
      },
      onTapCancel: onPressed == null ? null : () => onPressedChange(false),
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
          child: _isSaving && text.contains('Save')
              ? SizedBox(
                  height: 24,
                  width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.0,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        textColor ?? AppTheme.merchantPrimaryColor),
                  ),
                )
              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        color: textColor ?? AppTheme.merchantPrimaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: AppTheme.buttonText(
                        color: textColor ?? AppTheme.merchantPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ),
          );
  }
  
  // Custom neumorphic section
  Widget _buildNeumorphicSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppTheme.merchantPrimaryColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: AppTheme.headingSmall(),
                ),
              ],
            ),
          ),
          Container(
            decoration: AppTheme.getNeumorphismDecoration(
              color: AppTheme.neumorphismBackground,
              borderRadius: 20,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
} 