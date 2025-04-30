# Firebase Storage Setup Guide

Your app is experiencing a "Firebase Storage write permission denied" error. This means your Firebase Storage security rules need to be updated to allow authenticated users to upload files. Follow these steps to fix the issue:

## Step 1: Access Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project: "eat-ease-ed6aa"

## Step 2: Set Up Firebase Storage (if not already done)

1. In the left sidebar, click on "Storage"
2. If you haven't set up Storage yet, click "Get Started"
3. Choose a location for your storage bucket (select the region closest to your users)
4. When asked about security rules, select "Start in test mode" for now

## Step 3: Update Security Rules

1. After setting up Storage, go to the "Rules" tab
2. Replace the existing rules with the following:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      // Allow read/write access to all users for testing
      // WARNING: THESE RULES ARE INSECURE AND SHOULD ONLY BE USED FOR TESTING
      allow read, write: if true;
    }
  }
}
```

3. Click "Publish" to apply the rules

## Step 4: Test Your App

1. Go back to your Flutter app
2. Open the Product Form screen
3. Click the diagnostic button (question mark icon) in the top-right corner
4. Review the diagnostic results
5. Click "Test Upload" to verify that uploads are working

## Step 5: Use More Secure Rules (After Testing)

Once your app is working, you should replace the rules with more secure ones:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow authenticated users to read all files
    match /{allPaths=**} {
      allow read: if request.auth != null;
    }
    
    // Allow authenticated users to upload to their own directory
    match /products/{userId}/{fileName} {
      allow write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Additional Troubleshooting

If you're still encountering issues:

1. Make sure you're properly authenticated in the app
2. Check that your Firebase project is correctly configured
3. Verify that your storage bucket name matches in your Firebase configuration
4. Look at the debug logs in your Flutter console for specific error messages 