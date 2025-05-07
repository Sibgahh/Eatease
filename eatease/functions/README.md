# Order Status Update Cloud Function

This Cloud Function solves the permission issue with updating order status in the merchant orders screen.

## The Problem

Merchants were encountering a "permission denied" error when trying to update order statuses directly in Firestore. This happens because:

1. The Firestore security rules were restricting direct updates to orders
2. The existing code was trying to update orders directly from the client app

## The Solution

We've implemented a more secure and robust solution:

1. **Indirect Updates via Cloud Functions**: 
   - Instead of updating orders directly, merchants submit an "order status update request"
   - A Cloud Function processes these requests with admin privileges

2. **Security Rules**:
   - Added rules to allow merchants to create requests for their own orders
   - Restricted direct updates to orders to ensure they go through our business logic
   - Only Cloud Functions can perform the actual order updates

3. **Client-Side Changes**:
   - Updated the merchant orders screen to submit requests instead of direct updates
   - Added optimistic UI updates for a responsive user experience

## How It Works

1. When a merchant changes an order status, the app creates a new document in the `orderStatusRequests` collection
2. The `processOrderStatusUpdate` Cloud Function is triggered on document creation
3. The function verifies the merchant's permissions and the validity of the status change
4. If everything is valid, the function updates the order with admin privileges
5. The function updates the request document with success/failure status

## Deployment

To deploy the Cloud Functions:

```bash
cd functions
npm install
firebase deploy --only functions
```

## Security

This approach is more secure because:

1. All order updates go through our business logic
2. Merchants can only create requests for their own orders
3. All updates are validated before being applied
4. There's a complete audit trail of who changed what and when 