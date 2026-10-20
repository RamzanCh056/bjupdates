// lib/services/event_service.dart (updated with logging)

import 'dart:convert';
import 'dart:io';
import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'event_model.dart';
import 'dart:developer';

class EventService {
  final CollectionReference _eventsRef = FirebaseFirestore.instance.collection(
    'events',
  );
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Uuid _uuid = const Uuid();

  /// Stream all events
  Stream<List<Event1Model>> getAllEvents() {
    return _eventsRef.snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) =>
                Event1Model.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// Stream only the current user's events
  Stream<List<Event1Model>> getMyEvents(String uid) {
    return _eventsRef
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Event1Model.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  /// Create a new event (uploads image then writes Firestore doc)
  Future<void> createEvent({
    required String artistName,
    required String eventName,
    required String place,
    required String startTime,
    required String endTime,
    required String date,
    required File imageFile,
    required String ownerId,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    // 1) upload image
    final String imageId = _uuid.v4();
    final ref = _storage.ref().child('event_images/$imageId.jpg');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    // 2) assemble model & push to Firestore
    final event = Event1Model(
      id: '',
      imageUrl: imageUrl,
      artistName: artistName,
      eventName: eventName,
      place: place,
      startTime: startTime,
      endTime: endTime,
      date: date,
      ownerId: ownerId,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    await _eventsRef.add(event.toMap());

    // Log before calling cloud function
    log(
      '📱 Attempting to send event notification via cloud function for: $eventName',
    );

    // 🔔 Call cloud function to send push notifications to all users
    await _callSendEventNotificationCloudFunction(
      eventName: eventName,
      eventDescription:
          '$eventName by $artistName at $place on $date ($startTime - $endTime)',
      eventLocation: place,
      type: 'event',
    );
  }

  /// Delete an event and its associated image
  Future<void> deleteEvent(String eventId) async {
    try {
      // Get the event document to get the image URL
      final doc = await _eventsRef.doc(eventId).get();
      if (!doc.exists) {
        throw Exception('Event not found');
      }

      final data = doc.data() as Map<String, dynamic>;
      final imageUrl = data['imageUrl'] as String;

      // Delete the image from storage
      if (imageUrl.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(imageUrl);
          await ref.delete();
          log('✅ Deleted event image from storage');
        } catch (e) {
          log('❌ Error deleting image: $e');
          // Continue with event deletion even if image deletion fails
        }
      }

      // Delete the event document
      await _eventsRef.doc(eventId).delete();
      log('✅ Deleted event document from Firestore: $eventId');

      // 🔔 Notify users
      log('📱 Sending delete event notification to all users');
      await _sendEventNotificationToAllUsers(
        type: 'event_deleted',
        title: '🚫 Event Cancelled',
        body: 'An event has been removed — check the latest schedule.',
        message: 'An event was deleted or cancelled by the organizer.',
      );
    } catch (e) {
      log('❌ Failed to delete event: $e');
      throw Exception('Failed to delete event: $e');
    }
  }

  /// Update an existing event
  Future<void> updateEvent({
    required String eventId,
    required String artistName,
    required String eventName,
    required String place,
    required String startTime,
    required String endTime,
    required String date,
    File? newImageFile,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'artistName': artistName,
        'eventName': eventName,
        'place': place,
        'startTime': startTime,
        'endTime': endTime,
        'date': date,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      };

      // If a new image is provided, upload it and update the URL
      if (newImageFile != null) {
        final String imageId = _uuid.v4();
        final ref = _storage.ref().child('event_images/$imageId.jpg');
        await ref.putFile(newImageFile);
        final imageUrl = await ref.getDownloadURL();
        updateData['imageUrl'] = imageUrl;

        // Delete the old image
        final doc = await _eventsRef.doc(eventId).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final oldImageUrl = data['imageUrl'] as String;
          if (oldImageUrl.isNotEmpty) {
            try {
              final oldRef = _storage.refFromURL(oldImageUrl);
              await oldRef.delete();
              log('✅ Deleted old event image from storage');
            } catch (e) {
              log('❌ Error deleting old image: $e');
            }
          }
        }
        log('✅ Uploaded new event image to storage');
      }

      await _eventsRef.doc(eventId).update(updateData);
      log('✅ Updated event document in Firestore: $eventId');

      // 🔔 Notify users
      log('📱 Sending update event notification to all users for: $eventName');
      await _sendEventNotificationToAllUsers(
        type: 'event_update',
        title: '📅 Event Updated',
        body: '$eventName has been updated — check out new details!',
        message: 'The event "$eventName" has been updated by $artistName.',
      );
    } catch (e) {
      log('❌ Failed to update event: $e');
      throw Exception('Failed to update event: $e');
    }
  }

  /// Calls the sendEventNotification cloud function to broadcast push notifications to all users
  static const String _cloudFunctionUrl =
      'https://sendbeatjerkyeventnotification-6j4mf27zeq-uc.a.run.app';

  Future<void> _callSendEventNotificationCloudFunction({
    required String eventName,
    String? eventDescription,
    String? eventLocation,
    String type = 'event',
  }) async {
    log('📤 Calling cloud function at: $_cloudFunctionUrl');
    log(
      '📤 Request body: ${jsonEncode({'eventName': eventName, 'eventDescription': eventDescription ?? 'A new event has been created', 'eventLocation': eventLocation ?? '', 'type': type})}',
    );

    try {
      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'eventName': eventName,
          'eventDescription':
              eventDescription ?? 'A new event has been created',
          'eventLocation': eventLocation ?? '',
          'type': type,
        }),
      );

      log('📥 Cloud function response status: ${response.statusCode}');
      log('📥 Cloud function response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log(
          '✅ Event notification sent via cloud function: ${data['statistics'] ?? 'success'}',
        );
      } else {
        log(
          '❌ Cloud function returned ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      log('❌ Error calling sendEventNotification cloud function: $e');
    }
  }

  // 🔔 Reusable private method for sending + saving notifications (used for update/delete)
  Future<void> _sendEventNotificationToAllUsers({
    required String type,
    required String title,
    required String body,
    required String message,
  }) async {
    log('📱 Starting _sendEventNotificationToAllUsers for type: $type');

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        log('❌ No current user found, cannot send notifications');
        return;
      }
      log('✅ Current user: ${currentUser.uid}');

      final currentUserDoc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(currentUser.uid)
          .get();

      final currentUserName = currentUserDoc['firstName'] ?? 'Someone';
      log('✅ Current user name: $currentUserName');

      final usersSnapshot = await FirebaseFirestore.instance
          .collection('usersData')
          .get();
      log('📊 Total users found: ${usersSnapshot.docs.length}');

      final trigger = TriggerNotificationService();
      int pushSuccessCount = 0;
      int pushFailCount = 0;
      int notificationSaveCount = 0;

      for (var userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId == currentUser.uid) {
          log('⏭️ Skipping current user: $userId');
          continue;
        }

        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        log(
          '📱 Processing user: $userId, has token: ${fcmToken != null && fcmToken.isNotEmpty}',
        );

        // Send FCM push
        if (fcmToken != null && fcmToken.isNotEmpty) {
          try {
            log('📤 Sending push notification to user: $userId');
            await trigger.sendPushNotification(
              token: fcmToken,
              title: title,
              body: body,
            );
            pushSuccessCount++;
            log('✅ Push notification sent successfully to: $userId');
          } catch (e) {
            pushFailCount++;
            log('❌ Error sending push to $userId: $e');
          }
        }

        // Save notification in Firestore
        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(userId)
              .collection('userNotifications')
              .add({
                'type': type,
                'fromUserId': currentUser.uid,
                'fromUserName': currentUserName,
                'timestamp': FieldValue.serverTimestamp(),
                'message': message,
                'isRead': false,
              });
          notificationSaveCount++;
          log('✅ Notification saved to Firestore for: $userId');
        } catch (e) {
          log('❌ Error saving notification to Firestore for $userId: $e');
        }
      }

      log('📊 NOTIFICATION SUMMARY for type "$type":');
      log('   - Push successful: $pushSuccessCount');
      log('   - Push failed: $pushFailCount');
      log('   - Notifications saved: $notificationSaveCount');
      log(
        '   - Total users processed: ${usersSnapshot.docs.length - 1} (excluding sender)',
      );
    } catch (e) {
      log('❌ Fatal error in _sendEventNotificationToAllUsers: $e');
      log('   Stack trace: ${StackTrace.current}');
    }
  }
}
