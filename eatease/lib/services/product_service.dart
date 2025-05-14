import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../models/product_model.dart';
import '../models/merchant_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Collection reference
  CollectionReference get _products => _firestore.collection('products');

  // Get current merchant ID
  String? get currentMerchantId => _auth.currentUser?.uid;

  // Get all products for the current merchant
  Stream<List<ProductModel>> getMerchantProducts() {
    if (currentMerchantId == null) {
      return Stream.value([]);
    }
    
    return _products
      .where('merchantId', isEqualTo: currentMerchantId)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
  }

  // Get all products for a specific merchant
  Stream<List<ProductModel>> getMerchantProductsByMerchantId(String merchantId) {
    return _products
      .where('merchantId', isEqualTo: merchantId)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
  }

  // Get a single product by ID
  Future<ProductModel?> getProductById(String productId) async {
    try {
      final doc = await _products.doc(productId).get();
      if (!doc.exists) {
        return null;
      }
      return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // Test Firebase Storage connectivity
  Future<bool> testStorageConnection() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('ERROR: No authenticated user for storage test');
        return false;
      }
      
      print('DEBUG: Testing storage with user: ${currentUser.uid}');
      
      // First test default path
      print('DEBUG: Testing storage bucket name: ${_storage.ref().bucket}');
      
      // Try to list the root of the bucket
      print('DEBUG: Attempting to list root directory...');
      ListResult result = await _storage.ref().listAll();
      print('Storage connection test successful. Found ${result.items.length} items and ${result.prefixes.length} prefixes');
      
      // Try to create a test file
      final testBytes = utf8.encode('test data from ${currentUser.email} at ${DateTime.now().toIso8601String()}');
      final testFileName = 'test_connection_${DateTime.now().millisecondsSinceEpoch}.txt';
      final testRef = _storage.ref().child(testFileName);
      
      print('DEBUG: Attempting to upload test file: ${testRef.fullPath}');
      
      try {
        // Create a task and track its progress
        final UploadTask uploadTask = testRef.putData(testBytes, SettableMetadata(
          contentType: 'text/plain',
          customMetadata: {
            'uploadedBy': currentUser.uid,
            'test': 'true',
          }
        ));
        
        // Listen for state changes
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          print('DEBUG: Test upload progress: ${(snapshot.bytesTransferred / snapshot.totalBytes * 100).toStringAsFixed(2)}%');
        }, onError: (e) {
          print('ERROR: Test upload stream error: $e');
        });
        
        // Wait for completion
        final TaskSnapshot snapshot = await uploadTask;
        print('DEBUG: Test upload complete with state: ${snapshot.state}');
        
        // Get the URL
        final url = await testRef.getDownloadURL();
        print('Test file uploaded successfully: $url');
        
        // Delete the test file
        await testRef.delete();
        print('Test file deleted');
        
        return true;
      } catch (e) {
        print('Failed to create test file: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}, message: ${e.message}');
          
          if (e.code == 'unauthorized' || e.code == 'permission-denied') {
            print('PERMISSION ERROR: Current user ${currentUser.uid} does not have permission to write to ${testRef.fullPath}');
            print('Please check your Firebase Storage rules to ensure authenticated users can write');
          }
        }
        // Even if we can't create a file, we were able to list the bucket, so connection works partially
        return false;
      }
    } catch (e) {
      print('Storage connection test failed: $e');
      if (e is FirebaseException) {
        print('Firebase Storage error code: ${e.code}, message: ${e.message}');
      }
      return false;
    }
  }

  // Upload product image to Firebase Storage optimized for free tier
  Future<String> uploadProductImage(File imageFile) async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      print('ERROR: No authenticated user found');
      await _auth.signOut(); // Force sign out to ensure clean state
      throw Exception('You must be logged in to upload images. Please sign in again.');
    }

    if (currentMerchantId == null) {
      print('ERROR: No authenticated merchant found');
      throw Exception('No authenticated merchant found');
    }

    final String fileName = '${Uuid().v4()}${path.extension(imageFile.path)}';
    
    try {
      print('DEBUG: Preparing image for efficient upload: $fileName');
      print('DEBUG: File path: ${imageFile.path}');
      
      // Check if file exists
      if (!imageFile.existsSync()) {
        print('ERROR: Image file does not exist at ${imageFile.path}');
        return 'https://via.placeholder.com/400?text=Image+Not+Found';
      }
      
      // Get file size
      final int originalFileSize = await imageFile.length();
      print('DEBUG: Original file size: ${(originalFileSize / 1024).toStringAsFixed(2)} KB');
      
      // Create a file in temporary directory with a unique name
      final Directory tempDir = await getTemporaryDirectory();
      final String targetPath = path.join(tempDir.path, 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Compress the image
      int quality = 75; // Default quality - balanced between size and quality
      
      // Adjust quality based on file size
      if (originalFileSize > 1024 * 1024) { // > 1MB
        quality = 60; // More compression for larger files
      } else if (originalFileSize < 100 * 1024) { // < 100KB
        quality = 85; // Less compression for smaller files
      }
      
      print('DEBUG: Compressing image with quality: $quality');
      
      // Load image from file and resize/compress it
      final Uint8List? compressedImageBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: quality,
        minWidth: 800, // Reasonable size for most applications
        minHeight: 800,
      );
      
      // Check if compression succeeded
      if (compressedImageBytes == null) {
        print('WARNING: Image compression failed, using original file');
        // Continue with original file
      } else {
        // Write compressed data to temp file
        File compressedFile = File(targetPath);
        await compressedFile.writeAsBytes(compressedImageBytes);
        
        // Check compressed size
        final int compressedSize = await compressedFile.length();
        print('DEBUG: Compressed size: ${(compressedSize / 1024).toStringAsFixed(2)} KB - Saved ${((originalFileSize - compressedSize) / 1024).toStringAsFixed(2)} KB (${(100 - (compressedSize / originalFileSize * 100)).toStringAsFixed(0)}%)');
        
        // If compression actually made the file larger (rare), use original
        if (compressedSize >= originalFileSize) {
          print('DEBUG: Compression didn\'t reduce size, using original file');
        } else {
          // Use the compressed file for upload
          imageFile = compressedFile;
        }
      }
      
      // Create storage reference
      final String storagePath = 'products/${currentMerchantId}/${fileName}';
      print('DEBUG: Storage path: $storagePath');
      final Reference fileRef = _storage.ref().child(storagePath);
      
      // Set metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg', // Force JPEG for better compression
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'timestamp': DateTime.now().toIso8601String(),
        }
      );
      
      // Upload the file
      print('DEBUG: Starting upload...');
      final UploadTask uploadTask = fileRef.putFile(imageFile, metadata);
      
      // Listen for progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('DEBUG: Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
        onError: (error) {
          print('ERROR in upload progress: $error');
        }
      );
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      print('DEBUG: Upload complete: ${snapshot.bytesTransferred} bytes transferred');
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('DEBUG: Image uploaded - URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('UPLOAD ERROR: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
      }
      return 'https://via.placeholder.com/400?text=Upload+Error';
    }
  }

  // Function to upload multiple images with progress updates - optimized for free tier
  Stream<Map<String, dynamic>> uploadProductImagesWithProgress(List<File> imageFiles) {
    if (currentMerchantId == null) {
      print('ERROR: No authenticated merchant found for multiple uploads');
      throw Exception('No authenticated merchant found');
    }
    
    // Create a controller for our stream
    final controller = StreamController<Map<String, dynamic>>();
    
    // Track overall progress
    int totalFiles = imageFiles.length;
    int completedFiles = 0;
    List<String> uploadedUrls = [];
    List<String> errors = [];
    
    // If no files to upload, just complete the stream
    if (imageFiles.isEmpty) {
      print('DEBUG: No files to upload');
      controller.add({
        'isComplete': true,
        'progress': 1.0,
        'imageUrls': <String>[],
        'errors': <String>[],
      });
      controller.close();
      return controller.stream;
    }
    
    print('DEBUG: Starting optimized upload of $totalFiles files');
    
    // Process files one by one
    void processNextFile(int index) async {
      if (index >= imageFiles.length) {
        // All files processed
        print('DEBUG: All $completedFiles/$totalFiles files processed');
        controller.add({
          'isComplete': true,
          'progress': 1.0,
          'imageUrls': uploadedUrls,
          'errors': errors,
        });
        controller.close();
        return;
      }
      
      File imageFile = imageFiles[index];
      final String fileName = '${Uuid().v4()}.jpg';  // Always use .jpg for better compression
      
      print('DEBUG: Processing file ${index + 1}/$totalFiles: $fileName');
      
      try {
        // Update progress
        controller.add({
          'isComplete': false,
          'progress': index / totalFiles,
          'currentFile': index + 1,
          'totalFiles': totalFiles,
          'imageUrls': uploadedUrls,
          'errors': errors,
        });
        
        // Step 1: Check if file exists
        if (!imageFile.existsSync()) {
          print('ERROR: File does not exist: ${imageFile.path}');
          errors.add('File does not exist: ${path.basename(imageFile.path)}');
          completedFiles++;
          processNextFile(index + 1);
          return;
        }
        
        // Step 2: Compress image
        try {
          // Get original size
          final int originalSize = await imageFile.length();
          if (originalSize <= 0) {
            throw Exception('File is empty');
          }
          
          print('DEBUG: Original size: ${(originalSize / 1024).toStringAsFixed(2)} KB');
          
          // Create temp file for compressed image
          final Directory tempDir = await getTemporaryDirectory();
          final String tempFilePath = path.join(tempDir.path, 'comp_${index}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          
          // Determine compression level based on original size
          int quality = 75;
          if (originalSize > 1024 * 1024) { // > 1MB
            quality = 50; // Higher compression for batch uploads
          }
          
          // Compress with resolution limit for efficiency
          final Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(
            imageFile.absolute.path,
            quality: quality,
            minWidth: 800,
            minHeight: 800,
          );
          
          if (compressedBytes == null || compressedBytes.isEmpty) {
            print('WARNING: Compression failed, using original file');
          } else {
            // Save compressed file
            File compressedFile = File(tempFilePath);
            await compressedFile.writeAsBytes(compressedBytes);
            
            // Verify compressed size
            final int compressedSize = await compressedFile.length();
            print('DEBUG: Compressed to ${(compressedSize / 1024).toStringAsFixed(2)} KB (${(compressedSize / originalSize * 100).toStringAsFixed(0)}% of original)');
            
            if (compressedSize < originalSize) {
              imageFile = compressedFile;
            } else {
              print('DEBUG: Compression ineffective, using original');
            }
          }
        } catch (e) {
          print('WARNING: Error during compression: $e - will use original file');
          // Continue with original file
        }
        
        // Step 3: Upload the file
        final String storagePath = 'products/${currentMerchantId}/${fileName}';
        final Reference fileRef = _storage.ref().child(storagePath);
        
        // Set metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': currentMerchantId!,
            'batchUpload': 'true',
            'batchIndex': '$index',
            'timestamp': DateTime.now().toIso8601String(),
          }
        );
        
        // Create upload task
        print('DEBUG: Starting upload for file ${index + 1}...');
        final UploadTask uploadTask = fileRef.putFile(imageFile, metadata);
        
        // Track upload progress
        double lastReportedProgress = 0;
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double progress = snapshot.bytesTransferred / snapshot.totalBytes;
          
          // Only report progress changes of 10% or more to reduce updates
          if (progress - lastReportedProgress >= 0.1 || progress == 1.0) {
            lastReportedProgress = progress;
            
            // Calculate overall progress (completed files + progress on current file)
            double overallProgress = (index + progress) / totalFiles;
            
            controller.add({
              'isComplete': false,
              'progress': overallProgress,
              'currentFile': index + 1,
              'totalFiles': totalFiles,
              'currentProgress': progress,
              'imageUrls': uploadedUrls,
              'errors': errors,
            });
            
            print('DEBUG: File ${index + 1} progress: ${(progress * 100).toStringAsFixed(0)}%, overall: ${(overallProgress * 100).toStringAsFixed(0)}%');
          }
        }, onError: (e) {
          print('ERROR: Upload progress error: $e');
        });
        
        // Wait for upload to complete
        final TaskSnapshot snapshot = await uploadTask;
        
        // Get download URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        print('DEBUG: File ${index + 1} uploaded successfully: $downloadUrl');
        
        // Add to results
        uploadedUrls.add(downloadUrl);
        completedFiles++;
        
        // Add delay between uploads to avoid hitting rate limits
        if (index < imageFiles.length - 1) {
          await Future.delayed(Duration(milliseconds: 300));
        }
        
        // Process next file
        processNextFile(index + 1);
      } catch (e) {
        print('ERROR: Failed to upload file ${index + 1}: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}, message: ${e.message}');
        }
        
        errors.add('Error with file ${index + 1}: ${e.toString().substring(0, min(50, e.toString().length))}...');
        completedFiles++;
        
        // Update progress
        controller.add({
          'isComplete': false,
          'progress': completedFiles / totalFiles,
          'currentFile': index + 1,
          'totalFiles': totalFiles,
          'imageUrls': uploadedUrls,
          'errors': errors,
        });
        
        // Process next file (with slight delay)
        await Future.delayed(Duration(milliseconds: 500));
        processNextFile(index + 1);
      }
    }
    
    // Start processing files
    processNextFile(0);
    
    return controller.stream;
  }

  // Add a new product
  Future<String> addProduct(ProductModel product) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    try {
      print('Adding product: ${product.name} for merchant: $currentMerchantId');
      
      // Ensure imageUrls is not null
      final productData = product.copyWith(
        merchantId: currentMerchantId,
        createdAt: DateTime.now(),
        imageUrls: product.imageUrls.isEmpty ? [] : product.imageUrls,
      ).toMap();
      
      print('Product data prepared: ${productData.toString()}');
      
      // Use server timestamps for dates to avoid any issues with DateTime serialization
      final dataWithServerTimestamps = {
        ...productData,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('Attempting to add product to Firestore...');
      final DocumentReference docRef = await _products.add(dataWithServerTimestamps);
      print('Product added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
      }
      throw Exception('Failed to add product: $e');
    }
  }

  // Update an existing product
  Future<void> updateProduct(String productId, ProductModel product) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    try {
      print('Updating product: ${product.name} (ID: $productId)');
      
      // Ensure the product belongs to the current merchant
      final existingProduct = await getProductById(productId);
      if (existingProduct == null) {
        throw Exception('Product not found');
      }
      
      if (existingProduct.merchantId != currentMerchantId) {
        throw Exception('You do not have permission to edit this product');
      }
      
      final productData = product.copyWith(
        updatedAt: DateTime.now(),
        imageUrls: product.imageUrls.isEmpty ? [] : product.imageUrls,
      ).toMap();
      
      // Use server timestamp for updatedAt to avoid any DateTime serialization issues
      final dataWithServerTimestamp = {
        ...productData,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      print('Attempting to update product in Firestore...');
      await _products.doc(productId).update(dataWithServerTimestamp);
      print('Product updated successfully');
    } catch (e) {
      print('Error updating product: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
      }
      throw Exception('Failed to update product: $e');
    }
  }

  // Delete a product
  Future<void> deleteProduct(String productId) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    try {
      // Ensure the product belongs to the current merchant
      final existingProduct = await getProductById(productId);
      if (existingProduct == null) {
        throw Exception('Product not found');
      }
      
      if (existingProduct.merchantId != currentMerchantId) {
        throw Exception('You do not have permission to delete this product');
      }
      
      // Delete the product
      await _products.doc(productId).delete();
      
      // Delete associated images from storage
      for (final imageUrl in existingProduct.imageUrls) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting image: $e');
          // Continue with other image deletions even if one fails
        }
      }
    } catch (e) {
      print('Error deleting product: $e');
      throw Exception('Failed to delete product: $e');
    }
  }

  // Toggle product availability
  Future<void> toggleProductAvailability(String productId, bool isAvailable) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    try {
      // Ensure the product belongs to the current merchant
      final existingProduct = await getProductById(productId);
      if (existingProduct == null) {
        throw Exception('Product not found');
      }
      
      if (existingProduct.merchantId != currentMerchantId) {
        throw Exception('You do not have permission to modify this product');
      }
      
      await _products.doc(productId).update({
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error toggling product availability: $e');
      throw Exception('Failed to update product availability: $e');
    }
  }

  // Get all available products for customers
  Stream<List<ProductModel>> getAllAvailableProducts() {
    return _firestore
      .collection('products')
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        // Get all available products without additional merchant checks
        final products = snapshot.docs.map((doc) {
          return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        
        return products;
      });
  }

  // Diagnose Firebase Storage security rules issues
  Future<Map<String, dynamic>> diagnoseFbStorageSecurityRules() async {
    final Map<String, dynamic> results = {
      'canRead': false,
      'canWrite': false,
      'errors': <String>[],
      'message': '',
    };
    
    try {
      // First test: try to list root directory
      print('DEBUG: Testing read access to Firebase Storage root');
      try {
        final ListResult listResult = await _storage.ref().listAll();
        results['canRead'] = true;
        print('DEBUG: Successfully listed root - found ${listResult.items.length} items, ${listResult.prefixes.length} folders');
      } catch (e) {
        print('ERROR: Cannot list Firebase Storage root: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}, message: ${e.message}');
          if (e.code == 'permission-denied') {
            results['errors'].add('Storage read permission denied. Check Firebase rules.');
          }
        }
      }
      
      // Second test: try to create a test file
      print('DEBUG: Testing write access by uploading a small test file');
      final String testFileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';
      final Uint8List testData = utf8.encode('Test data for Firebase Storage rules check') as Uint8List;
      
      try {
        final Reference testRef = _storage.ref().child(testFileName);
        await testRef.putData(testData);
        
        // Try to get the URL to verify file was written
        final String downloadUrl = await testRef.getDownloadURL();
        results['canWrite'] = true;
        print('DEBUG: Successfully wrote test file: $downloadUrl');
        
        // Try to delete the test file
        await testRef.delete();
        print('DEBUG: Successfully deleted test file');
      } catch (e) {
        print('ERROR: Failed to write test file: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}, message: ${e.message}');
          if (e.code == 'permission-denied' || e.code == 'unauthorized') {
            results['errors'].add('Storage write permission denied. Check Firebase rules.');
          }
        }
      }
      
      // Create diagnostic message
      if (results['canRead'] && results['canWrite']) {
        results['message'] = 'Firebase Storage permissions look good';
      } else if (!results['canRead'] && !results['canWrite']) {
        results['message'] = 'No read or write permissions. Check your Firebase Storage rules and authentication.';
      } else if (results['canRead'] && !results['canWrite']) {
        results['message'] = 'Can read but cannot write to Firebase Storage. Check write rules.';
      } else {
        results['message'] = 'Can write but cannot read from Firebase Storage. Check read rules.';
      }
    } catch (e) {
      print('ERROR: General error during Firebase rules check: $e');
      results['errors'].add('General error testing Firebase Storage: $e');
    }
    
    return results;
  }

  // Simple diagnostic method to run before attempting uploads
  Future<Map<String, dynamic>> runDiagnostics() async {
    final Map<String, dynamic> results = {
      'storage': null,
      'auth': null,
      'firestore': null,
      'allPassed': false,
      'message': '',
    };
    
    try {
      // Check Firebase Auth
      results['auth'] = {
        'isAuthenticated': _auth.currentUser != null,
        'userId': _auth.currentUser?.uid ?? 'Not authenticated',
        'email': _auth.currentUser?.email ?? 'No email',
      };
      
      // Check Firebase Storage
      results['storage'] = await diagnoseFbStorageSecurityRules();
      
      // Check Firestore access
      try {
        // Try to read the merchant's own document
        if (_auth.currentUser != null) {
          final doc = await _firestore.collection('users').doc(_auth.currentUser!.uid).get();
          results['firestore'] = {
            'canRead': true,
            'docExists': doc.exists,
            'data': doc.exists ? 'Document exists' : 'Document does not exist',
          };
        } else {
          results['firestore'] = {
            'canRead': false,
            'message': 'Not authenticated',
          };
        }
      } catch (e) {
        print('ERROR: Firestore access failed: $e');
        results['firestore'] = {
          'canRead': false,
          'error': e.toString(),
        };
      }
      
      // Determine if all tests passed
      final bool authPassed = results['auth']['isAuthenticated'] == true;
      final bool storagePassed = results['storage']['canRead'] == true && 
                                 results['storage']['canWrite'] == true;
      final bool firestorePassed = results['firestore'] != null && 
                                  results['firestore']['canRead'] == true;
      
      results['allPassed'] = authPassed && storagePassed && firestorePassed;
      
      if (results['allPassed']) {
        results['message'] = 'All Firebase services are working correctly';
      } else {
        String message = 'Issues detected: ';
        if (!authPassed) message += 'Not authenticated. ';
        if (!storagePassed) message += results['storage']['message'] + ' ';
        if (!firestorePassed) message += 'Firestore access failed. ';
        results['message'] = message;
      }
    } catch (e) {
      print('ERROR during diagnostics: $e');
      results['message'] = 'Error running diagnostics: $e';
    }
    
    return results;
  }
} 