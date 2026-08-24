const { onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions/v2");
const admin = require("firebase-admin");

// Initialize Firebase Admin with error handling
try {
  if (!admin.apps.length) {
    admin.initializeApp();
    logger.info("Firebase Admin initialized successfully");
  }
} catch (error) {
  logger.error("Firebase Admin initialization failed:", error);
}

// Export the function using v2 syntax for better compatibility
exports.sendBeatJerkyArtistNotification = onRequest(
  {
    cors: true,
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async (req, res) => {
    // Set CORS headers manually
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    // Handle preflight requests
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    // Health check endpoint
    if (req.method === "GET") {
      res.status(200).json({
        status: "healthy",
        message: "BeatJerky Notification Function is running",
        timestamp: new Date().toISOString(),
        nodeVersion: process.version,
      });
      return;
    }

    try {
      // Check if it's a POST request
      if (req.method !== "POST") {
        res.status(405).json({
          success: false,
          error: "Method Not Allowed. Use POST or GET for health check.",
        });
        return;
      }

      // Get request body
      const requestBody = req.body;
      const eventName = requestBody.eventName;
      const eventDescription = requestBody.eventDescription;
      const eventLocation = requestBody.eventLocation;
      const type = requestBody.type || "event";

      // Validate required fields
      if (!eventName) {
        res.status(400).json({
          success: false,
          error: "Event name is required",
        });
        return;
      }

      logger.info("Received notification request for event:", eventName);

      // Step 1: Get all FCM tokens from Firestore
      logger.info("Fetching FCM tokens from Firestore...");

      const fcmTokensSnapshot = await admin
        .firestore()
        .collection("usersData")
        .where("fcmToken", "!=", null)
        .get();

      if (fcmTokensSnapshot.empty) {
        logger.warn("No FCM tokens found in database");
        res.status(200).json({
          success: true,
          message: "No users with FCM tokens found",
          sentCount: 0,
        });
        return;
      }

      // Extract valid tokens
      const tokens = [];
      fcmTokensSnapshot.forEach(doc => {
        const tokenData = doc.data();
        if (tokenData.fcmToken && tokenData.fcmToken.trim() !== "") {
          tokens.push(tokenData.fcmToken);
        }
      });

      logger.info("Found", tokens.length, "valid FCM tokens");

      if (tokens.length === 0) {
        res.status(200).json({
          success: true,
          message: "No valid FCM tokens found",
          sentCount: 0,
        });
        return;
      }

      // Step 2: Create notification payload
      const notificationBody = eventDescription || "A new Song has been Added to BeatJerky! Check it out now!";

      const notificationPayload = {
        notification: {
          title: "🎉 New Artist: " + eventName,
          body: notificationBody,
        },
        data: {
          type: type,
          eventName: eventName,
          eventDescription: eventDescription || "",
          eventLocation: eventLocation || "",
          isEvent: "true",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          screen: "event_details",
          timestamp: new Date().toISOString(),
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "event_notifications",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
        webpush: {
          notification: {
            icon: "/icon.png",
            badge: "/badge.png",
          },
        },
      };

      // Step 3: Send notifications to all tokens
      logger.info("Sending notifications to", tokens.length, "devices...");

      const batchSize = 500;
      const batches = [];

      // Split tokens into batches
      for (let i = 0; i < tokens.length; i += batchSize) {
        batches.push(tokens.slice(i, i + batchSize));
      }

      let totalSuccess = 0;
      let totalFailure = 0;
      const failedTokens = [];

      // Send notifications in batches
      for (let i = 0; i < batches.length; i++) {
        const batchTokens = batches[i];
        logger.info(
          "Processing batch",
          i + 1,
          "of",
          batches.length,
          "(" + batchTokens.length + " tokens)",
        );

        try {
          const response = await admin.messaging().sendEachForMulticast({
            ...notificationPayload,
            tokens: batchTokens,
          });

          totalSuccess += response.successCount;
          totalFailure += response.failureCount;

          // Check for failed tokens
          if (response.failureCount > 0) {
            response.responses.forEach((resp, idx) => {
              if (!resp.success) {
                const failedToken = batchTokens[idx];
                logger.warn(
                  "Failed for token:",
                  failedToken.substring(0, 20) + "...",
                  "Error:",
                  resp.error ? resp.error.message : "Unknown error",
                );

                failedTokens.push({
                  token: failedToken.substring(0, 20) + "...",
                  error: resp.error ? resp.error.message : "Unknown error",
                });
              }
            });
          }
        } catch (batchError) {
          logger.error("Error in batch", i + 1, ":", batchError);
          totalFailure += batchTokens.length;
        }
      }

      // Step 4: Return response
      logger.info("Notification sending completed");
      logger.info("Success:", totalSuccess, "Failed:", totalFailure);

      const successRate = ((totalSuccess / tokens.length) * 100).toFixed(2) + "%";

      res.status(200).json({
        success: true,
        message: "Notifications sent successfully",
        statistics: {
          totalTokens: tokens.length,
          sentSuccessfully: totalSuccess,
          failed: totalFailure,
          successRate: successRate,
        },
        eventDetails: {
          name: eventName,
          description: eventDescription,
          location: eventLocation,
          type: type,
        },
        failedTokens: failedTokens.length > 0 ? failedTokens.slice(0, 10) : [],
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error("Error in cloud function:", error);

      res.status(500).json({
        success: false,
        error: error.message,
        message: "Failed to send notifications",
      });
    }
  },
);