import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with options
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Explicitly get Firebase Storage instance
    print('Accessing Firebase Storage...');
    final storage = FirebaseStorage.instance;
    print('Firebase Storage bucket: ${storage.bucket}');
    
    runApp(const StorageTestApp());
  } catch (e) {
    print('FIREBASE INITIALIZATION ERROR: $e');
    
    // Show an error screen rather than crashing
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Firebase Initialization Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => main(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class StorageTestApp extends StatelessWidget {
  const StorageTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Storage Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StorageTestScreen(),
    );
  }
}

class StorageTestScreen extends StatefulWidget {
  const StorageTestScreen({super.key});

  @override
  State<StorageTestScreen> createState() => _StorageTestScreenState();
}

class _StorageTestScreenState extends State<StorageTestScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = false;
  String _status = 'Ready to test';
  
  // For displaying test results
  bool _isLoggedIn = false;
  bool _testSucceeded = false;
  String _resultMessage = '';
  String _errorDetails = '';
  
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }
  
  void _checkAuthStatus() {
    final user = _auth.currentUser;
    setState(() {
      _isLoggedIn = user != null;
      if (_isLoggedIn) {
        _status = 'Logged in as ${user!.email}';
      } else {
        _status = 'Not logged in';
      }
    });
  }
  
  // Test function that creates a file in Firebase Storage
  Future<void> _testFirebaseStorage() async {
    if (_auth.currentUser == null) {
      setState(() {
        _status = 'Please log in first';
        _testSucceeded = false;
        _resultMessage = 'Authentication required';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _status = 'Testing Firebase Storage...';
      _testSucceeded = false;
      _resultMessage = '';
      _errorDetails = '';
    });
    
    try {
      // Create a unique test file name
      final String testFileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';
      final String userId = _auth.currentUser!.uid;
      
      // Create test data
      final List<int> bytes = utf8.encode('Test file created at ${DateTime.now().toIso8601String()}');
      final Uint8List data = Uint8List.fromList(bytes);
      
      // Create the storage reference
      final Reference storageRef = _storage.ref();
      final Reference testFileRef = storageRef.child('test/$userId/$testFileName');
      
      // Try to upload
      setState(() {
        _status = 'Uploading test file...';
      });
      
      final UploadTask uploadTask = testFileRef.putData(data);
      
      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      setState(() {
        _isLoading = false;
        _testSucceeded = true;
        _status = 'Test successful!';
        _resultMessage = 'File uploaded successfully. URL: $downloadUrl';
      });
      
      // Try to delete the test file
      try {
        await testFileRef.delete();
        setState(() {
          _resultMessage += '\nTest file deleted successfully.';
        });
      } catch (e) {
        setState(() {
          _resultMessage += '\nCouldn\'t delete test file: $e';
        });
      }
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _testSucceeded = false;
        _status = 'Test failed';
        _resultMessage = 'Error: ${e.toString()}';
        
        if (e is FirebaseException) {
          _errorDetails = 'Firebase error code: ${e.code}\nMessage: ${e.message}';
        }
      });
    }
  }
  
  // Log in anonymously for testing
  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
      _status = 'Logging in anonymously...';
    });
    
    try {
      await _auth.signInAnonymously();
      _checkAuthStatus();
    } catch (e) {
      setState(() {
        _status = 'Login failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Sign out
  Future<void> _signOut() async {
    setState(() {
      _isLoading = true;
      _status = 'Signing out...';
    });
    
    try {
      await _auth.signOut();
      _checkAuthStatus();
    } catch (e) {
      setState(() {
        _status = 'Sign out failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Show Firebase Storage rules
  void _showRecommendedRules() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recommended Storage Rules'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Copy these rules to your Firebase Storage:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  'rules_version = \'2\';\n'
                  'service firebase.storage {\n'
                  '  match /b/{bucket}/o {\n'
                  '    match /{allPaths=**} {\n'
                  '      allow read, write: if request.auth != null;\n'
                  '    }\n'
                  '  }\n'
                  '}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Storage Test'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_status),
                    const SizedBox(height: 8),
                    Text('Bucket name: ${_storage.bucket}'),
                    const SizedBox(height: 8),
                    if (_isLoggedIn)
                      Text('User ID: ${_auth.currentUser!.uid}')
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Authentication buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoggedIn ? null : _signInAnonymously,
                    child: const Text('Sign In Anonymously'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoggedIn ? _signOut : null,
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Test button
            ElevatedButton(
              onPressed: _isLoading ? null : _testFirebaseStorage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Test Firebase Storage', style: TextStyle(fontSize: 16)),
            ),
            
            const SizedBox(height: 8),
            
            // Show rules button
            TextButton(
              onPressed: _showRecommendedRules,
              child: const Text('Show Recommended Rules'),
            ),
            
            const SizedBox(height: 24),
            
            // Results section
            if (_resultMessage.isNotEmpty)
              Card(
                color: _testSucceeded ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _testSucceeded ? 'Test Succeeded' : 'Test Failed',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: _testSucceeded ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(_resultMessage),
                      if (_errorDetails.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Error Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_errorDetails),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 