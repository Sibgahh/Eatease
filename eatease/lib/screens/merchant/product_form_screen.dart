import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../utils/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  final _prepTimeController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String _category = 'Main Course';
  bool _isAvailable = true;
  
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

  // Category options
  final List<String> _categoryOptions = [
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Sides',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Fast Food',
    'Healthy',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      // Editing existing product
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _prepTimeController.text = widget.product!.preparationTimeMinutes.toString();
      _category = widget.product!.category;
      _isAvailable = widget.product!.isAvailable;
      _existingImageUrls.addAll(widget.product!.imageUrls);
    } else {
      // Default values for new product
      _prepTimeController.text = '30';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _prepTimeController.dispose();
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

    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      setState(() {
        _errorMessage = 'Please add at least one image of your product';
      });
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
      // Upload any new images
      final List<String> allImageUrls = [..._existingImageUrls];
      
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
    if (imageUrls.isEmpty) {
      setState(() {
        _errorMessage = 'Failed to upload images';
        _isLoading = false;
        _isUploading = false;
      });
      return;
    }

    try {
      double price = 0;
      int prepTime = 30;
      
      try {
        price = double.parse(_priceController.text);
        prepTime = int.parse(_prepTimeController.text);
      } catch (e) {
        setState(() {
          _errorMessage = 'Invalid price or preparation time format';
          _isLoading = false;
          _isUploading = false;
        });
        return;
      }

      if (widget.product == null) {
        // Create new product
        try {
          final newProduct = ProductModel(
            id: const Uuid().v4(), // Will be replaced by Firestore
            merchantId: _productService.currentMerchantId ?? '',
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            imageUrls: imageUrls,
            category: _category,
            isAvailable: _isAvailable,
            preparationTimeMinutes: prepTime,
            createdAt: DateTime.now(),
          );

          await _productService.addProduct(newProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product added successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
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
          final updatedProduct = widget.product!.copyWith(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            price: price,
            imageUrls: imageUrls,
            category: _category,
            isAvailable: _isAvailable,
            preparationTimeMinutes: prepTime,
            updatedAt: DateTime.now(),
          );

          await _productService.updateProduct(widget.product!.id, updatedProduct);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Product updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add New Product' : 'Edit Product'),
        actions: [
          // Add a check auth button
          IconButton(
            icon: const Icon(Icons.security),
            tooltip: 'Check Auth',
            onPressed: _checkAuthStatus,
          ),
          // Add test storage rules button
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Test Storage Rules',
            onPressed: _testStorageRules,
          ),
          // Add a diagnostic button
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Run Diagnostics',
            onPressed: _runDiagnostics,
          ),
        ],
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
                      'Add at least one image of your product',
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
                          
                          // Existing images
                          for (int i = 0; i < _existingImageUrls.length; i++)
                            Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 120,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: NetworkImage(_existingImageUrls[i]),
                                      fit: BoxFit.cover,
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
                                    image: DecorationImage(
                                      image: FileImage(_newImageFiles[i]),
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
                              prefixText: '\$',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a price';
                              }
                              try {
                                final price = double.parse(value);
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Preparation Time (min)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter prep time';
                              }
                              try {
                                final time = int.parse(value);
                                if (time <= 0) {
                                  return 'Time must be > 0';
                                }
                              } catch (e) {
                                return 'Enter a valid number';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Additional Information
                    Text(
                      'Additional Information',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _categoryOptions.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _category = value;
                          });
                        }
                      },
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
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
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
  }
} 