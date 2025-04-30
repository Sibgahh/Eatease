// Pure Dart script to test Firebase Storage access

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// You'll need to copy these from your firebase_options.dart
final _firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyA2otloSpj6EKgTU2040JHXKKJ2OzODc6g', 
  appId: '1:754829269173:android:1e8d0f00df4136793986fc',
  messagingSenderId: '754829269173',
  projectId: 'eat-ease-ed6aa',
  storageBucket: 'eat-ease-ed6aa.appspot.com',
);

void main() async {
  print('Starting Firebase Storage test script...');

  try {
    // Initialize Firebase
    print('Initializing Firebase...');
    await Firebase.initializeApp(
      options: _firebaseOptions,
    );
    print('Firebase initialized successfully.');

    // Get Storage instance
    print('Getting Firebase Storage instance...');
    final storage = FirebaseStorage.instance;
    print('Storage bucket: ${storage.bucket}');

    // Sign in anonymously for testing
    print('Signing in anonymously...');
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    final user = userCredential.user;
    print('Signed in with user ID: ${user?.uid}');

    if (user == null) {
      print('ERROR: Failed to sign in anonymously');
      return;
    }

    // Create a test file
    final testFileName = 'test_file_${DateTime.now().millisecondsSinceEpoch}.txt';
    final testContent = 'Test file created at ${DateTime.now().toIso8601String()}';
    final bytes = utf8.encode(testContent);

    print('\nTesting Firebase Storage upload...');
    print('File name: $testFileName');
    print('Content: $testContent');

    // Try uploading to different locations
    final locations = [
      'test/$testFileName',
      'test/${user.uid}/$testFileName',
      'products/${user.uid}/$testFileName'
    ];

    for (final path in locations) {
      print('\nAttempting to upload to: $path');
      
      try {
        // Create reference
        final ref = storage.ref().child(path);
        print('Created reference: ${ref.fullPath}');
        
        // Upload
        print('Starting upload...');
        final task = ref.putData(bytes);
        
        // Wait for upload to complete
        final snapshot = await task;
        print('Upload complete, bytes: ${snapshot.bytesTransferred}');
        
        // Get download URL
        final url = await ref.getDownloadURL();
        print('SUCCESS! Download URL: $url');
        
        // Try to delete
        try {
          await ref.delete();
          print('Test file deleted');
        } catch (e) {
          print('Could not delete test file: $e');
        }
      } catch (e) {
        print('FAILED to upload to $path: $e');
        if (e is FirebaseException) {
          print('Firebase error code: ${e.code}, message: ${e.message}');
        }
      }
    }

    // Sign out
    print('\nSigning out...');
    await FirebaseAuth.instance.signOut();
    print('Signed out');

  } catch (e) {
    print('ERROR: $e');
  }

  print('\nTest completed.');
} 