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
  List<double> prices;
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
  ProductModel? _currentProduct;

  bool _isLoading = false;
  String? _errorMessage;
  String _category = 'Main Course';
  bool _isAvailable = true;
  
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

  final List<String> _categoryOptions = [
    'Appetizer',
    'Main Course',
    'Dessert',
    'Beverage',
    'Sides',
    'Breakfast',
    'Fast Food',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      // Initialize current product
      _currentProduct = widget.product;
      
      // Editing existing product
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _category = widget.product!.category;
      _isAvailable = widget.product!.isAvailable;
      _existingImageUrls.addAll(widget.product!.imageUrls);
      
      // Load customizations if they exist
      if (widget.product!.customizations != null) {
        _loadCustomizations(widget.product!.customizations!);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() {
        _errorMessage = null;
      });
      
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
      if (source == ImageSource.gallery) {
        final List<XFile> pickedFiles = await _imagePicker.pickMultiImage(
          imageQuality: 70,
        );
        
        if (pickedFiles.isNotEmpty) {
          setState(() {
            for (var file in pickedFiles) {
              _newImageFiles.add(File(file.path));
            }
          });
        }
      } else {
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
      final List<String> allImageUrls = [..._existingImageUrls];
      
      if (_newImageFiles.isNotEmpty) {
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
        }
        
        try {
          bool uploadFailed = false;
          
          _productService.uploadProductImagesWithProgress(_newImageFiles)
            .listen((uploadStatus) {
              setState(() {
                _uploadProgress = uploadStatus['progress'];
                _isUploading = !uploadStatus['isComplete'];
                _currentFileUploading = uploadStatus['currentFile'] ?? 0;
                
                if (!uploadStatus['isComplete']) {
                  _uploadStatus = 'Uploading image ${uploadStatus['currentFile']} of ${uploadStatus['totalFiles']}...';
                } else {
                  _uploadStatus = 'Processing...';
                  
                  if (uploadStatus['imageUrls'] != null) {
                    List<String> urls = List<String>.from(uploadStatus['imageUrls']);
                    allImageUrls.addAll(urls);
                  }
                  
                  if (uploadStatus['errors'] != null && uploadStatus['errors'].isNotEmpty) {
                    _errorMessage = 'Some images could not be uploaded: ${uploadStatus['errors'].length} errors';
                    
                    if (uploadStatus['imageUrls'] != null && 
                        (uploadStatus['imageUrls'] as List).isNotEmpty) {
                      _continueProductSave(allImageUrls);
                    } else {
                      uploadFailed = true;
                      _tryFallbackUpload(_newImageFiles, allImageUrls);
                    }
                  } else {
                    _continueProductSave(allImageUrls);
                  }
                }
              });
            }, onError: (e) {
              print('Error in batch upload: $e');
              uploadFailed = true;
              
              setState(() {
                _uploadStatus = 'Trying alternative upload method...';
              });
              
              _tryFallbackUpload(_newImageFiles, allImageUrls);
            });
        } catch (e) {
          print('Fatal error in batch upload: $e');
          
          setState(() {
            _uploadStatus = 'Trying alternative upload method...';
          });
          
          _tryFallbackUpload(_newImageFiles, allImageUrls);
        }
      } else {
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
  
  Future<void> _updateExistingProduct(List<String> imageUrls, double price, Map<String, dynamic> customizations) async {
    try {
      print('DEBUG: Starting product update');
      print('DEBUG: Current product ID: ${_currentProduct!.id}');
      
      // Rebuild the customizations map directly from current UI state
      final currentCustomizations = _buildCustomizationsMap();
      print('DEBUG: Current customizations from UI: $currentCustomizations');
      
      // If we already have a modified currentProduct from customization changes, use that as base
      // but update other fields that might have changed
      final updatedProduct = _currentProduct!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        imageUrls: imageUrls,
        isAvailable: _isAvailable,
        category: _category,
        // Ensure we're properly setting customizations to null if it's empty
        customizations: currentCustomizations.isEmpty ? null : currentCustomizations,
        updatedAt: DateTime.now(),
      );
      
      print('DEBUG: Updated product data: ${updatedProduct.toMap()}');
      print('DEBUG: Final customizations: ${updatedProduct.customizations}');
      
      // If we're explicitly setting customizations to null, make sure to clear it in Firestore
      if (currentCustomizations.isEmpty) {
        print('DEBUG: Clearing customizations in Firestore');
        await _productService.updateProductWithExplicitNullFields(
          _currentProduct!.id, 
          updatedProduct,
          ['customizations']
        );
      } else {
        await _productService.updateProduct(_currentProduct!.id, updatedProduct);
      }
      
      print('DEBUG: Product update successful');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('DEBUG: Error updating product: $e');
      setState(() {
        _errorMessage = 'Error updating product: $e';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  Future<void> _createNewProduct(List<String> imageUrls, double price, Map<String, dynamic> customizations) async {
    try {
      final newProduct = ProductModel(
        id: const Uuid().v4(),
        merchantId: _productService.currentMerchantId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: price,
        imageUrls: imageUrls,
        isAvailable: _isAvailable,
        category: _category,
        customizations: customizations.isEmpty ? null : customizations,
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
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating product: $e';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  Future<void> _continueProductSave(List<String> imageUrls) async {
    try {
      // Parse and validate price
      double price;
      try {
        // Fix price parsing by correctly handling the formatted number
        final priceText = _priceController.text.replaceAll('.', '');
        price = double.parse(priceText);
        
        print('DEBUG: Parsed price: $price');
      } catch (e) {
        setState(() {
          _errorMessage = 'Invalid price format';
          _isLoading = false;
          _isUploading = false;
        });
        return;
      }

      print('DEBUG: Starting product save...');
      
      // Build fresh customizations map directly from UI state
      final Map<String, dynamic> customizations = _buildCustomizationsMap();
      print('DEBUG: Customizations to save: $customizations');
      
      // Create or update product based on whether we're editing an existing product
      if (_currentProduct == null) {
        await _createNewProduct(imageUrls, price, customizations);
      } else {
        await _updateExistingProduct(imageUrls, price, customizations);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error processing product: $e';
        _isLoading = false;
        _isUploading = false;
      });
    }
  }

  void _loadCustomizations(Map<String, dynamic> customizations) {
    try {
      _customizationGroups.clear();
      
      customizations.forEach((title, data) {
        if (data is Map) {
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
      
      if (_customizationGroups.isEmpty) {
        _customizationGroups.add(CustomizationGroup(title: '', options: [''], prices: [0.0], isRequired: false));
      }
    } catch (e) {
      print('Error loading customizations: $e');
      _customizationGroups.add(CustomizationGroup(title: '', options: [''], prices: [0.0], isRequired: false));
    }
  }
  
  Map<String, dynamic> _buildCustomizationsMap() {
    final Map<String, dynamic> result = {};
    
    print('DEBUG: Building customizations map from ${_customizationGroups.length} groups');
    
    for (var group in _customizationGroups) {
      // Skip empty groups or groups with no title
      if (group.title.isEmpty || group.options.every((option) => option.isEmpty)) {
        print('DEBUG: Skipping empty group with title: "${group.title}"');
        continue;
      }
      
      // Filter out empty options
      final nonEmptyOptions = group.options.where((option) => option.isNotEmpty).toList();
      final relevantPrices = group.prices.sublist(0, nonEmptyOptions.length);
      
      // Only add groups with at least one option
      if (nonEmptyOptions.isNotEmpty) {
        print('DEBUG: Adding customization group "${group.title}" with ${nonEmptyOptions.length} options');
        result[group.title] = {
          'options': nonEmptyOptions,
          'prices': relevantPrices,
          'isRequired': group.isRequired,
        };
      } else {
        print('DEBUG: Skipping group "${group.title}" with no non-empty options');
      }
    }
    
    print('DEBUG: Final customizations map has ${result.length} groups: ${result.keys}');
    return result;
  }
  
  Widget _buildCustomizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Add customization options for your product if needed. This is optional.',
          style: AppTheme.bodyMedium(color: AppTheme.textSecondaryColor),
        ),
        const SizedBox(height: 16),
        
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
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  
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
                                    _customizationGroups[index].prices[optionIndex] = 0.0;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
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
        
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Customization Group'),
            onPressed: _addCustomizationGroup,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
  
  void _addCustomizationGroup() {
    setState(() {
      _customizationGroups.add(CustomizationGroup(
        title: '', 
        options: [''], 
        prices: [0.0],
        isRequired: false,
      ));
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New customization group added'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _addOption(int groupIndex) {
    setState(() {
      _customizationGroups[groupIndex].options.add('');
      _customizationGroups[groupIndex].prices.add(0.0);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New option added'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _removeOption(int groupIndex, int optionIndex) {
    setState(() {
      _customizationGroups[groupIndex].options.removeAt(optionIndex);
      
      if (optionIndex < _customizationGroups[groupIndex].prices.length) {
        _customizationGroups[groupIndex].prices.removeAt(optionIndex);
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Option removed'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  
  void _removeCustomizationGroup(int index) {
    // Store the group title before removing it for debug purposes
    final String groupTitle = index < _customizationGroups.length ? _customizationGroups[index].title : "unknown";

    setState(() {
      // Remove the group from the list
      if (index < _customizationGroups.length) {
        _customizationGroups.removeAt(index);
        
        // Update the current product's customizations if we're editing an existing product
        if (_currentProduct != null) {
          // Force rebuild the customizations map from scratch
          final customizations = _buildCustomizationsMap();
          print('DEBUG: Customizations after removing group "$groupTitle": $customizations');
          
          // Create a new instance of the current product with updated customizations
          _currentProduct = _currentProduct!.copyWith(
            customizations: customizations.isEmpty ? null : customizations,
            updatedAt: DateTime.now(),
          );
          
          print('DEBUG: Updated current product customizations: ${_currentProduct!.customizations}');
        }
      } else {
        print('ERROR: Attempted to remove non-existent customization group at index $index');
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Customization group removed'),
        duration: Duration(seconds: 1),
      ),
    );
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
                    
                    SizedBox(
                      height: 120,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
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
                    
                    Text(
                      'Customization Options',
                      style: AppTheme.headingMedium(),
                    ),
                    const SizedBox(height: 8),
                    
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
} 