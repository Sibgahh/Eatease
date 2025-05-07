# Merchant Orders Permission Fix Guide

This guide explains how to fix the "permission denied" error that occurs when merchants try to update order statuses.

## Overview of the Solution

The solution involves:

1. Using Firebase Cloud Functions to process order status updates with admin privileges
2. Updating the Firestore Security Rules to allow merchants to update their own orders
3. Creating a new collection for order status update requests

## Implementation Steps

### 1. Deploy the Firebase Cloud Function

The Cloud Function will handle order status updates with admin privileges, bypassing security rule restrictions.

```bash
# Navigate to the functions directory
cd functions

# Install dependencies
npm install

# Deploy the Cloud Function
firebase deploy --only functions
```

### 2. Update Firestore Security Rules

The updated security rules allow:
- Merchants to update their own orders directly
- Cloud Functions to process order status update requests

```bash
# Deploy updated security rules
firebase deploy --only firestore:rules
```

### 3. Test the Solution

1. Log in as a merchant
2. Navigate to the Orders screen
3. Try to update an order status (accept, mark as ready, or complete)
4. The update should now work without any permission errors

## Technical Details

### Client-Side Implementation

When a merchant updates an order status, we now:
1. Create a document in the `orderStatusRequests` collection
2. Wait for the Cloud Function to process this request
3. Update the UI optimistically for better user experience

### Cloud Function Implementation

The Cloud Function:
1. Listens for new documents in the `orderStatusRequests` collection
2. Verifies the merchant has permission to update the order
3. Validates the order status transition
4. Updates the order with admin privileges
5. Updates the request document with success/failure status

### Security Rules Changes

We've updated the security rules to:
1. Allow merchants to update their own orders directly
2. Allow order status update requests to be created by merchants
3. Allow Cloud Functions to update these requests

## Troubleshooting

If you still encounter permission issues:

1. Check the Firebase Function logs for errors:
   ```bash
   firebase functions:log
   ```

2. Verify the security rules have been deployed correctly:
   ```bash
   firebase deploy --only firestore:rules
   ```

3. Ensure the merchant is authenticated and has the correct permissions in the user document

## Quick Deployment

For Windows users, you can use the provided deployment script:
```
deploy-firebase.bat
```

For macOS/Linux users:
```bash
chmod +x deploy-firebase.sh
./deploy-firebase.sh
``` 