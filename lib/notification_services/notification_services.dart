import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../services/navigation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessageBackgroundHandle(RemoteMessage message) async {
  log("📱 Background Message received: ${message.messageId}");
  log("📱 Background Message data: ${message.data}");
  
  // Store notification data for navigation when app opens
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification_navigation', jsonEncode(message.data));
    log("💾 Stored background notification data");
  } catch (e) {
    log("❌ Error storing background notification: $e");
  }
  
  // Display notification
  display(message);
}

class NotificationService {
  // Local notifications plugin instance
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  RemoteMessage? initialMessage;

  // Initialize Firebase Messaging and notifications
  initInfo() async {
    // Set options for how notifications should be displayed when the app is in the foreground.
    initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Request permission (iOS-specific).
    var request = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: true,
      sound: true,
    );

    if (!kIsWeb) {
      await _subscribeToTopicSafe('social');
    }
    if (request.authorizationStatus == AuthorizationStatus.authorized ||
        request.authorizationStatus == AuthorizationStatus.provisional) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      var iosInitializationSettings = const DarwinInitializationSettings();

      final InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: iosInitializationSettings,
          );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("🧭 Local notification tapped: ${response.payload}");
          handleLocalNotificationTap(response.payload);
        },
      );
      await setupInteractedMessage();
      await getToken();
    }
  }

  // Handle notification taps
  Future<void> setupInteractedMessage() async {
    // Handle notification that opened app from terminated state
    initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      log("📱 App opened from terminated state via notification");
      log("📱 Initial message data: ${initialMessage!.data}");
      
      // Store for navigation after app initializes
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(seconds: 2)); // Wait for app to be ready
        await handleNotificationTap(initialMessage!);
      });
    }

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log("📱 App opened from background via notification");
      log("📱 Message data: ${message.data}");
      handleNotificationTap(message);
    });

    // Handle notification received when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log("📱 Foreground notification received");
      log("📱 Message data: ${message.data}");
      if (message.notification != null) {
        display(message); // Show local notification
      }
    });
  }

  /// Handle notification tap - routes to appropriate screen
  Future<void> handleNotificationTap(RemoteMessage message) async {
    try {
      log("🧭 Handling notification tap");
      log("🧭 Message data: ${message.data}");
      
      if (message.data.isEmpty) {
        log("⚠️ No data in notification, navigating to notifications screen");
        // Navigate to notifications screen if no specific data
        final context = navigatorKey.currentContext;
        if (context != null) {
          // Import needed for NotificationScreen
          // This will be handled by NavigationService
        }
        return;
      }

      // Use NavigationService to handle routing
      await NavigationService.handleNotificationNavigation(message.data);
    } catch (e) {
      log("❌ Error handling notification tap: $e");
    }
  }

  /// Handle local notification taps (from foreground notifications)
  void handleLocalNotificationTap(String? payload) {
    log("🧭 Local notification tap with payload: $payload");
    if (payload != null && payload.isNotEmpty) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        // Wait a bit for context to be available
        Future.delayed(const Duration(milliseconds: 500), () {
          NavigationService.handleNotificationNavigation(data);
        });
      } catch (e) {
        log("❌ Error parsing local notification payload: $e");
      }
    }
  }

  /// On iOS, FCM needs an APNS token first. Simulators often never provide one.
  static Future<bool> _iosPushReady() async {
    if (kIsWeb || !Platform.isIOS) return true;
    for (var attempt = 0; attempt < 5; attempt++) {
      final apns = await FirebaseMessaging.instance.getAPNSToken();
      if (apns != null) return true;
      await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
    return false;
  }

  static Future<void> _subscribeToTopicSafe(String topic) async {
    if (kIsWeb) return;
    try {
      if (!await _iosPushReady()) {
        debugPrint(
          '⚠️ Skipping topic "$topic"; APNS token unavailable (simulator or pending)',
        );
        return;
      }
      await FirebaseMessaging.instance.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('⚠️ subscribeToTopic("$topic") failed: $e');
    }
  }

  // Get FCM token for device
  static Future<String?> getToken() async {
    if (kIsWeb) return null;
    try {
      if (!await _iosPushReady()) {
        debugPrint(
          '⚠️ APNS token not available; skipping FCM token (normal on iOS Simulator)',
        );
        return null;
      }
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('🔑 FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('⚠️ FCM getToken failed: $e');
      return null;
    }
  }
}

// Display local notification
void display(RemoteMessage message) async {
  debugPrint('Got a message: ${message.notification!.title}');
  debugPrint('Message data: ${message.data}');

  try {
    // Define an Android notification channel.
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      '0',
      'Beat Jerky',
      description: 'Show Beat Jerky Notification',
      importance: Importance.max,
    );

    // Define Android-specific notification details.
    AndroidNotificationDetails notificationDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: 'your channel Description',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'ticker',
      icon: '@mipmap/ic_launcher',
    );

    // Define iOS-specific notification details.
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    // Combine Android and iOS details
    NotificationDetails notificationDetailsBoth = NotificationDetails(
      android: notificationDetails,
      iOS: darwinNotificationDetails,
    );

    // Create payload from message data
    final payload = jsonEncode(message.data);
    debugPrint('Displaying notification with payload: $payload');

    // Display the notification
    await FlutterLocalNotificationsPlugin().show(
      0,
      message.notification!.title,
      message.notification!.body,
      notificationDetailsBoth,
      payload: payload,
    );

    // Refresh notifications list in ProfileViewModel after displaying local notification
  } on Exception catch (e) {
    log("Error Local Notification: ${e.toString()}");
  }
}
