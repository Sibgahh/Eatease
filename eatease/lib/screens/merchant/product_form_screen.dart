import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

// Class to manage product customization groups
class CustomizationGroup {
  String title;
  List<String> options;
  List<double> prices; // Add prices for each option
  bool isRequired;
  
  CustomizationGroup({
    required this.title, 
    required this.options,
    required this.prices,
    this.isRequired = false,
  });
}

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
<<<<<<< Updated upstream
  // Removing preparation time controller
  // final _prepTimeController = TextEditingController();
=======
  ProductModel? _currentProduct;
>>>>>>> Stashed changes

  bool _isLoading = false;
  String? _errorMessage;
  // Removing category variable
  String _category = 'Main Course';
  bool _isAvailable = true;
  bool _isAddingImageUrl = false;
  
  // Customization options
  List<CustomizationGroup> _customizationGroups = [];
  
  // Image upload progress tracking
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String _uploadStatus = '';
  int _currentFileUploading = 0;
  int _totalFilesToUpload = 0;
  
  // Image handling
  final List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];
  final ImagePicker _imagePicker = ImagePicker();

  // Removing category options
  final List<String> _categoryOptions = [
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Sides',
    'Breakfast',
    'Fast Food',
  ];

  String? _previewImageUrl;
  bool _isLoadingPreview = false;
  bool _previewError = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      // Editing existing product
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      // Removing preparation time initialization
      // _prepTimeController.text = widget.product!.preparationTimeMinutes.toString();
      // Removing category initialization
      _category = widget.product!.category;
      _isAvailable = widget.product!.isAvailable;
      _existingImageUrls.addAll(widget.product!.imageUrls);
      
      // Load customizations if they exist
      if (widget.product!.customizations != null) {
        _loadCustomizations(widget.product!.customizations!);
      }
    } else {
      // Default values for new product
      // Removing preparation time default
      // _prepTimeController.text = '30';
      
      // Add one empty customization group for new products
      _customizationGroups.add(CustomizationGroup(title: '', options: ['', ''], prices: [0.0, 0.0], isRequired: false));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
<<<<<<< Updated upstream
    // Removing preparation time disposal
    // _prepTimeController.dispose();
=======
    _imageUrlController.dispose();
>>>>>>> Stashed changes
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      // Set temporary loading state
      setState(() {
        _errorMessage = null;
      });
      
      // Show a bottom sheet with options
      showModalBottomSheet(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Take a Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing image picker: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accessing image picker: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      // For gallery, allow multiple selection
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
          imageQuality: 70, // Lower quality for faster upload
        );
        
        if (pickedFiles.isNotEmpty) {
          setState(() {
            for (var file in pickedFiles) {
              _newImageFiles.add(File(file.path));
            }
          });
        }
      } else {
        // For camera, just pick one image
        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 70,
        );
        
        if (pickedFile != null) {
          setState(() {
            _newImageFiles.add(File(pickedFile.path));
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      // Show error in a non-blocking way
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = _newImageFiles.isNotEmpty;
      _uploadProgress = 0.0;
      _errorMessage = null;
      _totalFilesToUpload = _newImageFiles.length;
      _currentFileUploading = 0;
      _uploadStatus = _newImageFiles.isNotEmpty 
          ? 'Preparing to upload images...' 
          : 'Processing...';
    });

    try {
      // Debug print to check image URLs
      print('Existing image URLs before save: $_existingImageUrls');
      
      // Upload any new images
      final List<String> allImageUrls = [..._existingImageUrls];
      
      // Debug printout to verify URLs are retained
      print('All image URLs before upload: $allImageUrls');
      
      if (_newImageFiles.isNotEmpty) {
        // First try the diagnostics to see if Firebase Storage is working
        try {
          final diagnosticResults = await _productService.diagnoseFbStorageSecurityRules();
          if (!diagnosticResults['canWrite']) {
            setState(() {
              _errorMessage = 'Firebase Storage write permission denied. Please check your authentication and storage rules.';
              _isLoading = false;
              _isUploading = false;
            });
            return;
          }
        } catch (e) {
          print('Warning: Failed to run storage diagnostics: $e');
          // Continue anyway since this is just a pre-check
        }
        
        // Use the new streaming upload method if we have files to upload
        try {
          bool uploadFailed = false;
          
          _productService.uploadProductImagesWithProgress(_newImageFiles)
            .listen((uploadStatus) {
              // Update the UI with progress
              setState(() {
                _uploadProgress = uploadStatus['progress'];
                _isUploading = !uploadStatus['isComplete'];
                _currentFileUploading = uploadStatus['currentFile'] ?? 0;
                
                if (!uploadStatus['isComplete']) {
                  _uploadStatus = 'Uploading image ${uploadStatus['currentFile']} of ${uploadStatus['totalFiles']}...';
                } else {
                  _uploadStatus = 'Processing...';
                  
                  // Add the URLs to our list
                  if (uploadStatus['imageUrls'] != null) {
                    List<String> urls = List<String>.from(uploadStatus['imageUrls']);
                    allImageUrls.addAll(urls);
                  }
                  
                  // Check for errors
                  if (uploadStatus['errors'] != null && uploadStatus['errors'].isNotEmpty) {
                    _errorMessage = 'Some images could not be uploaded: ${uploadStatus['errors'].length} errors';
                    
                    // If we have errors, but also at least one successful upload, continue
                    if (uploadStatus['imageUrls'] != null && 
                        (uploadStatus['imageUrls'] as List).isNotEmpty) {
                      _continueProductSave(allImageUrls);
                    } else {
                      // If we have no successful uploads, try the fallback
                      uploadFailed = true;
                      _tryFallbackUpload(_newImageFiles, allImageUrls);
                    }
                  } else {
                    // If no errors, continue with product save
                    _continueProductSave(allImageUrls);
                  }
                }
              });
            }, onError: (e) {
              print('Error in batch upload: $e');
              uploadFailed = true;
              
              // Try fallback method with single images
              setState(() {
                _uploadStatus = 'Trying alternative upload method...';
              });
              
              _tryFallbackUpload(_newImageFiles, allImageUrls);
            });
        } catch (e) {
          print('Fatal error in batch upload: $e');
          
          // Try fallback method with single images
          setState(() {
            _uploadStatus = 'Trying alternative upload method...';
          });
          
          _tryFallbackUpload(_newImageFiles, allImageUrls);
        }
      } else {
        // If no new images, continue with existing ones
        _continueProductSave(allImageUrls);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error saving product: $e';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }
  
  // Fallback method that tries to upload images one by one directly
  Future<void> _tryFallbackUpload(List<File> files, List<String> existingUrls) async {
    setState(() {
      _uploadStatus = 'Trying fallback upload method...';
      _errorMessage = null;
    });
    
    final List<String> allImageUrls = [...existingUrls];
    final List<String> errors = [];
    
    for (int i = 0; i < files.length; i++) {
      try {
        setState(() {
          _uploadProgress = i / files.length;
          _currentFileUploading = i + 1;
          _uploadStatus = 'Uploading image ${i + 1} of ${files.length} (fallback method)...';
        });
        
        // Try direct upload for this single file
        final url = await _productService.uploadProductImage(files[i]);
        
        if (!url.contains('placeholder')) {
          allImageUrls.add(url);
        } else {
          errors.add('Failed to upload image ${i + 1}');
        }
      } catch (e) {
        print('Error in fallback upload for image ${i + 1}: $e');
        errors.add('Error with image ${i + 1}: $e');
      }
    }
    
    // Check if we have at least one successful upload
    if (allImageUrls.isNotEmpty) {
      if (errors.isNotEmpty) {
        setState(() {
          _errorMessage = 'Some images failed to upload (${errors.length} errors)';
        });
      }
      
      _continueProductSave(allImageUrls);
    } else {
      setState(() {
        _errorMessage = 'Failed to upload any images. Please try again later.';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }
  
  // Continue with product save after images are processed
  Future<void> _continueProductSave(List<String> imageUrls) async {
    try {
      // Debug print to verify we have all images including URLs
      print('Image URLs to save: $imageUrls');
      
      double price = 0;
      
      try {
        price = double.parse(_priceController.text.replaceAll('.', ''));
      } catch (e) {
        setState(() {
          _errorMessage = 'Invalid price format';
          _isLoading = false;
          _isUploading = false;
        });
        return;
      }

      // Process customization groups to a format that can be stored
      final Map<String, dynamic> customizations = _buildCustomizationsMap();

      if (widget.product == null) {
        // Create new product
        try {
          // Make sure we have at least an empty list for images
          final List<String> finalImageUrls = imageUrls.isEmpty 
              ? [] 
              : imageUrls;
          
          final newProduct = ProductModel(
            id: const Uuid().v4(), // Will be replaced by Firestore
            merchantId: _productService.currentMerchantId ?? '',
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            imageUrls: finalImageUrls,
            isAvailable: _isAvailable,
            category: _category,
            customizations: customizations.isNotEmpty ? customizations : null,
            createdAt: DateTime.now(),
          );
          
          // Debug print product before saving
          print('New product to save: ${newProduct.toString()}');
          print('Image URLs in new product: ${newProduct.imageUrls}');

          await _productService.addProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product added successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Close the form screen and indicate success
            Navigator.pop(context, true);
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Error adding product: $e';
            _isLoading = false;
            _isUploading = false;
          });
        }
      } else {
        // Update existing product
        try {
          // Make sure we have at least an empty list for images
          final List<String> finalImageUrls = imageUrls.isEmpty 
              ? [] 
              : imageUrls;
          
          final updatedProduct = widget.product!.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            imageUrls: finalImageUrls,
            isAvailable: _isAvailable,
            category: _category,
            customizations: customizations.isNotEmpty ? customizations : null,
            updatedAt: DateTime.now(),
          );
          
          // Debug print product before saving
          print('Updated product to save: ${updatedProduct.toString()}');
          print('Image URLs in updated product: ${updatedProduct.imageUrls}');

          await _productService.updateProduct(widget.product!.id, updatedProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Close the form screen and refresh the product list
            Navigator.pop(context, true); // Return true to indicate the product was updated
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Error updating product: $e';
            _isLoading = false;
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing product: $e';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  // Add a method to check authentication status
  void _checkAuthStatus() {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not authenticated! Please log out and log back in.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Authenticated as: ${user.email} (${user.uid})'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Add a test method to verify Firebase Storage rules
  Future<void> _testStorageRules() async {
    setState(() {
      _isLoading = true;
      _uploadStatus = 'Testing Firebase Storage rules...';
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Not authenticated. Please sign in first.');
      }
      
      // Create a test file in memory
      final List<int> bytes = utf8.encode('Test file created by ${user.email} at ${DateTime.now().toIso8601String()}');
      final testFileName = 'test_file_${DateTime.now().millisecondsSinceEpoch}.txt';
      
      // Reference to Firebase Storage
      final FirebaseStorage storage = FirebaseStorage.instance;
      final storageRef = storage.ref();
      
      // First test: top level directory
      final testRef1 = storageRef.child(testFileName);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to create test file at root level...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      try {
        // Try to upload to root
        await testRef1.putData(Uint8List.fromList(bytes));
        final url1 = await testRef1.getDownloadURL();
        
        // If successful, show success and try to delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Root level write successful: $url1'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        try {
          await testRef1.delete();
          print('Root test file deleted');
        } catch (e) {
          print('Could not delete root test file: $e');
        }
      } catch (e) {
        print('Root level test failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Root level access denied: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Second test: user directory
      await Future.delayed(Duration(milliseconds: 500)); // Small delay between tests
      final testRef2 = storageRef.child('users/${user.uid}/$testFileName');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to create test file in user directory...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      try {
        // Try to upload to user directory
        await testRef2.putData(Uint8List.fromList(bytes));
        final url2 = await testRef2.getDownloadURL();
        
        // If successful, show success and try to delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User directory write successful: $url2'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        try {
          await testRef2.delete();
          print('User directory test file deleted');
        } catch (e) {
          print('Could not delete user directory test file: $e');
        }
      } catch (e) {
        print('User directory test failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User directory access denied: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Third test: products directory
      await Future.delayed(Duration(milliseconds: 500)); // Small delay between tests
      final testRef3 = storageRef.child('products/${user.uid}/$testFileName');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to create test file in products directory...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      try {
        // Try to upload to products directory
        await testRef3.putData(Uint8List.fromList(bytes));
        final url3 = await testRef3.getDownloadURL();
        
        // If successful, show success and try to delete
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Products directory write successful: $url3'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        try {
          await testRef3.delete();
          print('Products directory test file deleted');
        } catch (e) {
          print('Could not delete products directory test file: $e');
        }
      } catch (e) {
        print('Products directory test failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Products directory access denied: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      // Show final instructions
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Firebase Storage Rules Test'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Test completed. If all tests failed, you need to fix your Firebase Storage rules.'),
              const SizedBox(height: 16),
              const Text('Recommended rules:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'rules_version = \'2\';\n'
                  'service firebase.storage {\n'
                  '  match /b/{bucket}/o {\n'
                  '    match /{allPaths=**} {\n'
                  '      allow read, write: if request.auth != null;\n'
                  '    }\n'
                  '  }\n'
                  '}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Load customizations from product data
  void _loadCustomizations(Map<String, dynamic> customizations) {
    try {
      _customizationGroups.clear();
      
      customizations.forEach((title, data) {
        if (data is Map) {
          // New format with options and prices
          List<String> options = [];
          List<double> prices = [];
          bool isRequired = false;
          
          if (data['options'] is List) {
            options = List<String>.from(data['options'].map((option) => option.toString()));
          }
          
          if (data['prices'] is List) {
            prices = List<double>.from(data['prices'].map((price) => 
                price is num ? price.toDouble() : 0.0));
          } else {
            // Create default prices (0.0) for each option
            prices = List<double>.filled(options.length, 0.0);
          }
          
          if (data['isRequired'] is bool) {
            isRequired = data['isRequired'];
          }
          
          _customizationGroups.add(
            CustomizationGroup(
              title: title,
              options: options,
              prices: prices,
              isRequired: isRequired,
            ),
          );
        } else if (data is List) {
          // Old format with just options, no prices
          List<String> options = List<String>.from(data.map((option) => option.toString()));
          List<double> prices = List<double>.filled(options.length, 0.0);
          
          _customizationGroups.add(
            CustomizationGroup(
              title: title,
              options: options,
              prices: prices,
              isRequired: false,
            ),
          );
        }
      });
      
      // If no customizations were loaded, add an empty group
      if (_customizationGroups.isEmpty) {
        _customizationGroups.add(CustomizationGroup(title: '', options: [''], prices: [0.0], isRequired: false));
      }
    } catch (e) {
      print('Error loading customizations: $e');
      // Add an empty group if there was an error
      _customizationGroups.add(CustomizationGroup(title: '', options: [''], prices: [0.0], isRequired: false));
    }
  }
  
  // Build customizations map for saving to Firestore
  Map<String, dynamic> _buildCustomizationsMap() {
    final Map<String, dynamic> result = {};
    
    for (var group in _customizationGroups) {
      // Skip empty groups or groups with no title
      if (group.title.isEmpty || group.options.every((option) => option.isEmpty)) {
        continue;
      }
      
      // Filter out empty options
      final nonEmptyOptions = group.options.where((option) => option.isNotEmpty).toList();
      
      // Only add groups with at least one option
      if (nonEmptyOptions.isNotEmpty) {
        result[group.title] = {
          'options': nonEmptyOptions,
          'prices': group.prices.sublist(0, nonEmptyOptions.length),
          'isRequired': group.isRequired,
        };
      }
    }
    
    return result;
  }
  
  // Build the customization section UI
  Widget _buildCustomizationSection() {
    return Column(
      children: [
        // List existing customization groups
        ..._customizationGroups.asMap().entries.map((entry) {
          final index = entry.key;
          final group = entry.value;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group header with delete button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Customization Group ${index + 1}',
                          style: AppTheme.getTextStyle(16, AppTheme.bold, AppTheme.textPrimaryColor),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeCustomizationGroup(index),
                        tooltip: 'Remove this group',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Group title field
                  TextFormField(
                    initialValue: group.title,
                    decoration: const InputDecoration(
                      labelText: 'Group Title (e.g., "Size", "Toppings")',
                      border: OutlineInputBorder(),
                      hintText: 'Enter a title for this customization group',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _customizationGroups[index].title = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Required toggle
                  SwitchListTile(
                    title: const Text('Required Selection'),
                    subtitle: const Text('Customer must select one option'),
                    value: group.isRequired,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    onChanged: (value) {
                      setState(() {
                        _customizationGroups[index].isRequired = value;
                      });
                    },
                  ),
                  const Divider(),
                  
                  // Options header
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Text(
                            'Option Name',
                            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                          ),
                        ),
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Additional Price',
                            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                          ),
                        ),
                        const SizedBox(width: 40), // Space for delete button
                      ],
                    ),
                  ),
                  
                  // Options list
                  ...group.options.asMap().entries.map((optionEntry) {
                    final optionIndex = optionEntry.key;
                    final option = optionEntry.value;
                    final price = optionIndex < group.prices.length 
                        ? group.prices[optionIndex] 
                        : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Option name
                          Expanded(
                            flex: 6,
                            child: TextFormField(
                              initialValue: option,
                              decoration: InputDecoration(
                                hintText: 'Option ${optionIndex + 1}',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _customizationGroups[index].options[optionIndex] = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Option price
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              initialValue: price.toString(),
                              decoration: const InputDecoration(
                                prefixText: 'Rp ',
                                hintText: '0',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                TextInputFormatter.withFunction((oldValue, newValue) {
                                  if (newValue.text.isEmpty) {
                                    return newValue;
                                  }
                                  // Format the number with thousand separators
                                  final value = int.parse(newValue.text);
                                  final formatted = NumberFormat("#,###", "id_ID").format(value);
                                  return TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(offset: formatted.length),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  try {
                                    if (value.isEmpty) {
                                      _customizationGroups[index].prices[optionIndex] = 0.0;
                                    } else {
                                      _customizationGroups[index].prices[optionIndex] = 
                                          double.parse(value.replaceAll('.', ''));
                                    }
                                  } catch (e) {
                                    // Ignore parse errors
                                    _customizationGroups[index].prices[optionIndex] = 0.0;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Delete option button
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            onPressed: () => _removeOption(index, optionIndex),
                            tooltip: 'Remove this option',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms);
                  }).toList(),
                  
                  // Add option button
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Option'),
                    onPressed: () => _addOption(index),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 300.ms);
        }).toList(),
        
        // Add group button
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Customization Group'),
            onPressed: _addCustomizationGroup,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  // Add a new customization group
  void _addCustomizationGroup() {
    setState(() {
      _customizationGroups.add(CustomizationGroup(
        title: '', 
        options: [''], 
        prices: [0.0],
        isRequired: false,
      ));
    });
    
    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New customization group added'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  // Add a new option to a group
  void _addOption(int groupIndex) {
    setState(() {
      _customizationGroups[groupIndex].options.add('');
      _customizationGroups[groupIndex].prices.add(0.0);
    });
    
    // Show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New option added'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  // Remove an option from a group
  void _removeOption(int groupIndex, int optionIndex) {
    if (_customizationGroups[groupIndex].options.length > 1) {
      setState(() {
        _customizationGroups[groupIndex].options.removeAt(optionIndex);
        
        // Also remove the corresponding price
        if (optionIndex < _customizationGroups[groupIndex].prices.length) {
          _customizationGroups[groupIndex].prices.removeAt(optionIndex);
        }
      });
      
      // Show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Option removed'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // Don't remove the last option, just clear it
      setState(() {
        _customizationGroups[groupIndex].options[optionIndex] = '';
        _customizationGroups[groupIndex].prices[optionIndex] = 0.0;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least one option. Field cleared instead.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
  
  // Remove a customization group
  void _removeCustomizationGroup(int index) {
    if (_customizationGroups.length > 1) {
      setState(() {
        _customizationGroups.removeAt(index);
      });
      
      // Show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customization group removed'),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      // Don't remove the last group, just clear it
      setState(() {
        _customizationGroups[index] = CustomizationGroup(
          title: '', 
          options: [''], 
          prices: [0.0],
          isRequired: false,
        );
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least one customization group. Fields cleared instead.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    
    // Check if URL is not empty
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an image URL'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Basic URL validation
    bool isValidUrl = Uri.tryParse(url)?.hasAbsolutePath ?? false;
    if (!isValidUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Check for common image extensions
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    bool hasImageExtension = imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
    
    if (!hasImageExtension && !url.contains('image')) {
      // Show confirmation dialog if URL doesn't seem to be an image
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Image URL'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The URL you entered does not appear to be a direct image link. Are you sure this is a valid image URL?',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'For best results, use a direct link to an image file (ends with .jpg, .png, etc.)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmAddImageUrl(url);
              },
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );
    } else {
      _confirmAddImageUrl(url);
    }
  }
  
  void _confirmAddImageUrl(String url) {
    // Debug print before adding URL
    print('Adding image URL to _existingImageUrls: $url');
    print('Current _existingImageUrls before adding: $_existingImageUrls');
    
    setState(() {
      // Make sure we're adding to the existing URLs list
      if (_existingImageUrls.contains(url)) {
        // Don't add duplicates
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This image URL is already added'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      _existingImageUrls.add(url);
      _imageUrlController.clear();
      _isAddingImageUrl = false;
      _previewImageUrl = null;
      _previewError = false;
    });

    // Debug print after adding URL
    print('Updated _existingImageUrls after adding: $_existingImageUrls');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Image URL added successfully'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // Show the image in a dialog
            showDialog(
              context: context,
              builder: (context) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(
                      title: const Text('Image Preview'),
                      leading: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text('Error loading image: $error'),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
          textColor: Colors.white,
        ),
      ),
    );
  }

  void _toggleAddImageUrl() {
    setState(() {
      _isAddingImageUrl = !_isAddingImageUrl;
      if (!_isAddingImageUrl) {
        _imageUrlController.clear();
        _previewImageUrl = null;
        _previewError = false;
      }
    });
  }

  void _loadImagePreview() {
    final url = _imageUrlController.text.trim();
    
    // Check if URL is not empty and valid
    if (url.isEmpty || !(Uri.tryParse(url)?.hasAbsolutePath ?? false)) {
      setState(() {
        _previewImageUrl = null;
        _previewError = false;
        _isLoadingPreview = false;
      });
      return;
    }
    
    // Reset error state and set loading
    setState(() {
      _isLoadingPreview = true;
      _previewError = false;
      _previewImageUrl = url;
    });
    
    // Create a temporary Image widget to test loading
    final testImage = Image.network(
      url,
      key: UniqueKey(),
    );
    
    final imageStream = testImage.image.resolve(const ImageConfiguration());
    
    // Listen to the image stream to detect loading success/failure
    imageStream.addListener(ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() {
            _isLoadingPreview = false;
            _previewError = false;
          });
        }
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        if (mounted) {
          setState(() {
            _isLoadingPreview = false;
            _previewError = true;
          });
          print('Error loading image preview: $exception');
        }
      },
    ));
  }

  // Build the URL input section for adding an image by URL
  Widget _buildUrlInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Image from URL',
          style: AppTheme.headingSmall(),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter a direct link to an image (JPG, PNG, etc.)',
          style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
                onChanged: (_) => _loadImagePreview(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _addImageUrl,
              child: const Text('Add'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                backgroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_previewImageUrl != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Image Preview:',
                  style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                ),
                const SizedBox(height: 8),
                _isLoadingPreview
                    ? Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 8),
                            Text(
                              'Loading image...',
                              style: AppTheme.bodyMedium(),
                            ),
                          ],
                        ))
                    : _previewError
                        ? Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 42),
                                const SizedBox(height: 8),
                                Text(
                                  'Invalid image URL',
                                  style: AppTheme.bodyMedium(color: Colors.red),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please enter a direct link to an image',
                                  style: AppTheme.bodySmall(color: Colors.red.shade800),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _previewImageUrl!,
                              fit: BoxFit.cover,
                              height: 200,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                Future.microtask(() {
                                  setState(() {
                                    _previewError = true;
                                  });
                                });
                                return Container(
                                  height: 150,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.error_outline, color: Colors.red, size: 32),
                                  ),
                                );
                              },
                            ),
                          ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Cancel'),
              onPressed: _toggleAddImageUrl,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addImageUrl() {
    final url = _imageUrlController.text.trim();
    
    // Check if URL is not empty
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an image URL')),
      );
      return;
    }
    
    // Basic URL validation
    bool isValidUrl = Uri.tryParse(url)?.hasAbsolutePath ?? false;
    if (!isValidUrl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL')),
      );
      return;
    }
    
    // Check for common image extensions
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];
    bool hasImageExtension = imageExtensions.any((ext) => url.toLowerCase().endsWith(ext));
    
    if (!hasImageExtension && !url.contains('image')) {
      // Show confirmation dialog if URL doesn't seem to be an image
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Image URL'),
          content: const Text(
            'The URL you entered does not appear to be a direct image link. '
            'Are you sure this is a valid image URL?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmAddImageUrl(url);
              },
              child: const Text('Add Anyway'),
            ),
          ],
        ),
      );
    } else {
      _confirmAddImageUrl(url);
    }
  }
  
  void _confirmAddImageUrl(String url) {
    setState(() {
      _existingImageUrls.add(url);
      _imageUrlController.clear();
      _isAddingImageUrl = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image URL added'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _toggleAddImageUrl() {
    setState(() {
      _isAddingImageUrl = !_isAddingImageUrl;
      if (!_isAddingImageUrl) {
        _imageUrlController.clear();
        _previewImageUrl = null;
        _previewError = false;
      }
    });
  }

  void _loadImagePreview() {
    final url = _imageUrlController.text.trim();
    
    // Check if URL is not empty and valid
    if (url.isEmpty || !(Uri.tryParse(url)?.hasAbsolutePath ?? false)) {
      setState(() {
        _previewImageUrl = null;
        _previewError = false;
      });
      return;
    }
    
    setState(() {
      _isLoadingPreview = true;
      _previewError = false;
      _previewImageUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add New Product' : 'Edit Product'),
        backgroundColor: AppTheme.merchantPrimaryColor,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading) ...[
                    // Image upload progress indicator
                    SizedBox(
                      width: 250,
                      child: Column(
                        children: [
                          Text(
                            _uploadStatus,
                            textAlign: TextAlign.center,
                            style: AppTheme.bodyMedium(),
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toInt()}%',
                            style: AppTheme.bodyMedium(),
                          ),
                          if (_currentFileUploading > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'File $_currentFileUploading of $_totalFilesToUpload',
                              style: AppTheme.bodySmall(color: AppTheme.textSecondaryColor),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    // Standard loading indicator
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: AppTheme.bodyMedium(),
                    ),
                  ],
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Images Section
                    Text(
                      'Product Images',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add images of your product (optional)',
                      style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image Gallery
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // Add image button
                          InkWell(
                            onTap: _pickImage,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate, 
                                    size: 40,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Add Image',
                                    style: AppTheme.bodyMedium(color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
<<<<<<< Updated upstream
                          // Add from URL button
=======
>>>>>>> Stashed changes
                          InkWell(
                            onTap: _toggleAddImageUrl,
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.link, 
                                    size: 40,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
<<<<<<< Updated upstream
                                    'Add from URL',
=======
                                    'Add URL',
>>>>>>> Stashed changes
                                    style: AppTheme.bodyMedium(color: AppTheme.primaryColor),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
<<<<<<< Updated upstream
                          // Existing images
=======
>>>>>>> Stashed changes
                          for (int i = 0; i < _existingImageUrls.length; i++)
                            Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _existingImageUrls[i],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey.shade200,
                                          child: const Center(
                                            child: Icon(Icons.error_outline, color: Colors.red, size: 32),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 13,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(i),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          
                          // New images
                          for (int i = 0; i < _newImageFiles.length; i++)
                            Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _newImageFiles[i],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  right: 13,
                                  child: GestureDetector(
                                    onTap: () => _removeNewImage(i),
                                    child: const CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Colors.red,
                                      child: Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    if (_isAddingImageUrl)
<<<<<<< Updated upstream
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildUrlInputSection(),
                        ),
                      ),
=======
                      _buildUrlInputSection(),
>>>>>>> Stashed changes
                    
                    const SizedBox(height: 24),
                    
                    // Basic Information
                    Text(
                      'Basic Information',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a product name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Price',
                              border: OutlineInputBorder(),
                              prefixText: 'Rp ',
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                if (newValue.text.isEmpty) {
                                  return newValue;
                                }
                                // Format the number with thousand separators
                                final value = int.parse(newValue.text);
                                final formatted = NumberFormat("#,###", "id_ID").format(value);
                                return TextEditingValue(
                                  text: formatted,
                                  selection: TextSelection.collapsed(offset: formatted.length),
                                );
                              }),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a price';
                              }
                              try {
                                final price = double.parse(value.replaceAll('.', ''));
                                if (price <= 0) {
                                  return 'Price must be greater than zero';
                                }
                              } catch (e) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Food Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categoryOptions.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _category = newValue;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a category';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Additional Information
                    Text(
                      'Additional Information',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 16),
                    
                    SwitchListTile(
                      title: const Text('Available for Order'),
                      subtitle: const Text('Toggle to make this item available or unavailable'),
                      value: _isAvailable,
                      onChanged: (value) {
                        setState(() {
                          _isAvailable = value;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Customization Options
                    Text(
                      'Customization Options',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add customization options for your product (e.g., size, toppings, spice level)',
                      style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildCustomizationSection(),
                    
                    const SizedBox(height: 24),
                    
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: AppTheme.errorColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTheme.bodyMedium(color: AppTheme.errorColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        child: Text(
                          widget.product == null ? 'Add Product' : 'Update Product',
                          style: AppTheme.buttonText(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

<<<<<<< Updated upstream
  // Add a method to run diagnostics
  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _uploadStatus = 'Running Firebase diagnostics...';
    });
    
    try {
      final diagnosticResults = await _productService.runDiagnostics();
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Firebase Diagnostics'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Overall: ${diagnosticResults['allPassed'] ? '✅ Passed' : '❌ Failed'}'),
                  const Divider(),
                  Text('Message: ${diagnosticResults['message']}'),
                  const Divider(),
                  const Text('Authentication:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Logged in: ${diagnosticResults['auth']['isAuthenticated'] ? '✅ Yes' : '❌ No'}'),
                  Text('User ID: ${diagnosticResults['auth']['userId']}'),
                  const Divider(),
                  const Text('Storage:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Can Read: ${diagnosticResults['storage']['canRead'] ? '✅ Yes' : '❌ No'}'),
                  Text('Can Write: ${diagnosticResults['storage']['canWrite'] ? '✅ Yes' : '❌ No'}'),
                  if (diagnosticResults['storage']['errors'] != null && 
                      (diagnosticResults['storage']['errors'] as List).isNotEmpty)
                    Text('Errors: ${(diagnosticResults['storage']['errors'] as List).join(', ')}'),
                  const Divider(),
                  const Text('Firestore:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Can Access: ${diagnosticResults['firestore']['canRead'] ? '✅ Yes' : '❌ No'}'),
                  if (diagnosticResults['firestore']['docExists'] != null)
                    Text('User Document: ${diagnosticResults['firestore']['docExists'] ? '✅ Exists' : '❌ Missing'}'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Run a simple upload test
                  _testSingleImageUpload();
                },
                child: const Text('Test Upload'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error running diagnostics: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Test a single image upload
  Future<void> _testSingleImageUpload() async {
    try {
      // First ensure we have a test image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      setState(() {
        _isLoading = true;
        _uploadStatus = 'Testing image upload...';
      });
      
      // Create a test file
      final File testFile = File(pickedFile.path);
      final fileSize = await testFile.length();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Testing upload of image (${(fileSize / 1024).toStringAsFixed(1)} KB)'),
          ),
        );
      }
      
      // Attempt direct upload using the simplified method
      final String url = await _productService.uploadProductImage(testFile);
      
      if (url.contains('placeholder')) {
        // Upload failed
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload test failed: $url'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Upload succeeded
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload test succeeded!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Show the image in a dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Upload Successful'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    url,
                    height: 200,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
=======
  Widget _buildUrlInputSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter image URL',
            style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/image.jpg',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => _loadImagePreview(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addImageUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Add'),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleAddImageUrl,
              ),
            ],
          ),
          
          if (_previewImageUrl != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _previewImageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        // Image has loaded successfully
                        return child;
                      }
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                  (loadingProgress.expectedTotalBytes ?? 1)
>>>>>>> Stashed changes
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
<<<<<<< Updated upstream
                      return const Center(
                        child: Text('Error loading image'),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('URL: $url', style: const TextStyle(fontSize: 12)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error testing upload: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
=======
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Invalid image URL',
                              style: AppTheme.bodySmall(color: Colors.red),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
>>>>>>> Stashed changes
  }
} 