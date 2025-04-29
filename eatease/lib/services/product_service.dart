import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../models/product_model.dart';

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

  // Upload product image to Firebase Storage
  Future<String> uploadProductImage(File imageFile) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    final String fileName = '${Uuid().v4()}${path.extension(imageFile.path)}';
    final Reference storageRef = _storage.ref().child('products/$currentMerchantId/$fileName');
    
    try {
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading product image: $e');
      throw Exception('Failed to upload image');
    }
  }

  // Add a new product
  Future<String> addProduct(ProductModel product) async {
    if (currentMerchantId == null) {
      throw Exception('No authenticated merchant found');
    }

    try {
      final productData = product.copyWith(
        merchantId: currentMerchantId,
        createdAt: DateTime.now(),
      ).toMap();
      
      final DocumentReference docRef = await _products.add(productData);
      return docRef.id;
    } catch (e) {
      print('Error adding product: $e');
      throw Exception('Failed to add product: $e');
    }
  }

  // Update an existing product
  Future<void> updateProduct(String productId, ProductModel product) async {
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
        throw Exception('You do not have permission to edit this product');
      }
      
      final productData = product.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();
      
      await _products.doc(productId).update(productData);
    } catch (e) {
      print('Error updating product: $e');
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
        return snapshot.docs.map((doc) {
          return ProductModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
      });
  }
} 