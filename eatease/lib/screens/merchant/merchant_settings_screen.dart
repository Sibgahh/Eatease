import 'package:flutter/material.dart';
import '../../models/merchant_model.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../routes.dart';

class MerchantSettingsScreen extends StatefulWidget {
  final bool redirectedForSetup;
  
  const MerchantSettingsScreen({
    Key? key, 
    this.redirectedForSetup = false,
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
  
  @override
  void initState() {
    super.initState();
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
  
  Future<void> _loadMerchantData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final merchantModel = await _authService.getCurrentMerchantModel();
      
      if (merchantModel != null) {
        _storeNameController.text = merchantModel.storeName ?? '';
        _storeDescriptionController.text = merchantModel.storeDescription ?? '';
        _storeAddressController.text = merchantModel.storeAddress ?? '';
        _phoneController.text = merchantModel.phoneNumber;
        
        // Check if the merchant has the required fields
        _hasRequiredFields = merchantModel.isStoreConfigured();
      }
    } catch (e) {
      _errorMessage = 'Error loading merchant data: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Store Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 2,
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
        actions: [
          // Save button in app bar for quick access
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Settings',
            onPressed: _isSaving ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with gradient
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.blue.shade700, Colors.blue.shade500],
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.store_rounded,
                              color: Colors.white.withOpacity(0.9),
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Store Information',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Manage your store details visible to customers',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.redirectedForSetup)
                          Container(
                            padding: const EdgeInsets.all(20.0),
                            margin: const EdgeInsets.only(bottom: 24.0),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12.0),
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
                        
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Basic Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 20.0),
                              
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
                                    borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                  prefixIcon: const Icon(Icons.store, color: Colors.blue),
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
                                    borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                  prefixIcon: const Icon(Icons.description, color: Colors.blue),
                                ),
                                maxLines: 3,
                              ),
                              const SizedBox(height: 24.0),
                              
                              const Text(
                                'Contact Information',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
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
                                    borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                  prefixIcon: const Icon(Icons.location_on, color: Colors.blue),
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
                                    borderSide: BorderSide(color: Colors.blue.shade500, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.all(16),
                                  prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32.0),
                              
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
                              
                              SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _hasRequiredFields || widget.redirectedForSetup
          ? null
          : FutureBuilder<String>(
              future: _authService.getUserRole(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox();
                }
                
                final userRole = snapshot.data ?? 'merchant';
                return BottomNavBar(
                  currentIndex: 3,  // Settings tab
                  userRole: userRole,
                );
              },
            ),
    );
  }
} 