import 'package:cloud_functions/cloud_functions.dart';

class TriggerNotificationService {

Future<void> sendPushNotification({
  required String token,
  required String title,
  required String body,
}) async {
  try {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('sendPushNotification');

    final result = await callable.call(<String, dynamic>{
      'token': token,
      'title': title,
      'body': body,
    });

    print("Notification sent: ${result.data}");
  } catch (e) {
    print("Error sending push notification: $e");
  }
}
}
