const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * HTTP callable function to update order status
 * This allows direct updates from the client app without going through Firestore security rules
 */
exports.updateOrderStatus = functions.https.onCall(async (data, context) => {
  // Check if the user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "You must be logged in to update an order status."
    );
  }

  // Extract data from the request
  const { orderId, newStatus } = data;
  const merchantId = context.auth.uid;

  // Validate input
  if (!orderId || !newStatus) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "The function must be called with orderId and newStatus arguments."
    );
  }

  try {
    // Get the order document
    const orderRef = admin.firestore().collection("orders").doc(orderId);
    const orderDoc = await orderRef.get();

    if (!orderDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        `Order ${orderId} does not exist`
      );
    }

    const orderData = orderDoc.data();

    // Verify that the merchant is authorized to update this order
    if (orderData.merchantId !== merchantId) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "You are not authorized to update this order"
      );
    }

    // Verify the status transition is valid
    const currentStatus = orderData.status;
    if (!isValidStatusTransition(currentStatus, newStatus)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        `Invalid status transition from ${currentStatus} to ${newStatus}`
      );
    }

    // Prepare update data
    const updateData = {
      status: newStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Add completedAt timestamp if order is being completed
    if (newStatus === "completed") {
      updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    // Update the order document
    await orderRef.update(updateData);

    // Log success
    functions.logger.info(
      `Successfully updated order ${orderId} status to ${newStatus}`,
      { orderId, merchantId, newStatus }
    );

    return { success: true, message: `Order status updated to ${newStatus}` };
  } catch (error) {
    // Log error
    functions.logger.error(
      `Error updating order ${orderId} status: ${error.message}`,
      { orderId, merchantId, newStatus, error: error.message }
    );

    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Cloud Function that listens for new documents in the 'orderStatusRequests' collection
 * and updates the corresponding order document in the 'orders' collection.
 * 
 * This function runs with admin privileges, bypassing security rules.
 */
exports.processOrderStatusUpdate = functions.firestore
  .document("orderStatusRequests/{requestId}")
  .onCreate(async (snapshot, context) => {
    const requestData = snapshot.data();
    
    // Extract data from the request
    const orderId = requestData.orderId;
    const merchantId = requestData.merchantId;
    const newStatus = requestData.newStatus;
    
    try {
      // Validate the request data
      if (!orderId || !merchantId || !newStatus) {
        throw new Error("Missing required fields in request data");
      }
      
      // Get the order document
      const orderRef = admin.firestore().collection("orders").doc(orderId);
      const orderDoc = await orderRef.get();
      
      if (!orderDoc.exists) {
        throw new Error(`Order ${orderId} does not exist`);
      }
      
      const orderData = orderDoc.data();
      
      // Verify that the merchant is authorized to update this order
      if (orderData.merchantId !== merchantId) {
        throw new Error("Merchant is not authorized to update this order");
      }
      
      // Verify the status transition is valid
      const currentStatus = orderData.status;
      if (!isValidStatusTransition(currentStatus, newStatus)) {
        throw new Error(`Invalid status transition from ${currentStatus} to ${newStatus}`);
      }
      
      // Prepare update data
      const updateData = {
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      // Add completedAt timestamp if order is being completed
      if (newStatus === "completed") {
        updateData.completedAt = admin.firestore.FieldValue.serverTimestamp();
      }
      
      // Update the order document
      await orderRef.update(updateData);
      
      // Update the request document with success status
      await snapshot.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        success: true,
      });
      
      // Log success
      functions.logger.info(
        `Successfully updated order ${orderId} status to ${newStatus}`,
        { orderId, merchantId, newStatus }
      );
      
      return { success: true };
    } catch (error) {
      // Update the request document with error status
      await snapshot.ref.update({
        processed: true,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        success: false,
        error: error.message,
      });
      
      // Log error
      functions.logger.error(
        `Error updating order ${orderId} status: ${error.message}`,
        { orderId, merchantId, newStatus, error: error.message }
      );
      
      return { success: false, error: error.message };
    }
  });

/**
 * Validates whether a status transition is allowed
 */
function isValidStatusTransition(currentStatus, newStatus) {
  // Define valid status transitions
  const validTransitions = {
    "pending": ["preparing", "cancelled"],
    "preparing": ["ready", "cancelled"],
    "ready": ["completed", "cancelled"],
    "completed": [], // Terminal state
    "cancelled": [], // Terminal state
  };
  
  // Check if the current status has the new status as a valid transition
  return validTransitions[currentStatus] && 
         validTransitions[currentStatus].includes(newStatus);
} 