import 'package:cloud_firestore/cloud_firestore.dart' as firestore;

class DataService {
  final firestore.FirebaseFirestore _firestore = firestore.FirebaseFirestore.instance;

  // Check Firestore Connection
  Future<bool> checkConnection() async {
    try {
      await _firestore.collection('test').doc('test').set({
        'timestamp': firestore.FieldValue.serverTimestamp(),
      });
      await _firestore.collection('test').doc('test').delete();
      return true;
    } catch (e) {
      print('Firestore connection error: $e');
      return false;
    }
  }

  // Generic method to add a document to a collection
  Future<String> addDocument(String collection, Map<String, dynamic> data) async {
    try {
      firestore.DocumentReference docRef = await _firestore.collection(collection).add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add document: $e');
    }
  }

  // Generic method to get a document
  Future<Map<String, dynamic>?> getDocument(String collection, String documentId) async {
    try {
      firestore.DocumentSnapshot doc = await _firestore.collection(collection).doc(documentId).get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      return null;
    } catch (e) {
      throw Exception('Failed to get document: $e');
    }
  }

  // Generic method to update a document
  Future<void> updateDocument(String collection, String documentId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(collection).doc(documentId).update(data);
    } catch (e) {
      throw Exception('Failed to update document: $e');
    }
  }

  // Generic method to delete a document
  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      await _firestore.collection(collection).doc(documentId).delete();
    } catch (e) {
      throw Exception('Failed to delete document: $e');
    }
  }

  // Generic method to query documents
  Future<List<Map<String, dynamic>>> queryDocuments(
    String collection, {
    List<List<dynamic>> whereConditions = const [],
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    try {
      firestore.Query query = _firestore.collection(collection);
      
      // Apply where conditions if any
      for (var condition in whereConditions) {
        if (condition.length == 3) {
          query = query.where(condition[0], isEqualTo: condition[1]);
        }
      }
      
      // Apply orderBy if specified
      if (orderBy != null) {
        query = query.orderBy(orderBy, descending: descending);
      }
      
      // Apply limit if specified
      if (limit != null) {
        query = query.limit(limit);
      }
      
      // Execute the query
      firestore.QuerySnapshot snapshot = await query.get();
      
      // Return the results
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Failed to query documents: $e');
    }
  }
} 