// import 'dart:convert';

// import 'package:flutter/cupertino.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';
// import 'package:http/http.dart' as http;
// import 'package:provider/provider.dart';

// import '../../providers/users_provider/current_user_provider.dart';
// import '../../repo/api_consts.dart';
// import 'notification_model.dart';
// import 'notification_provider.dart';

// class NotificationService {
//   Future<bool> getCurrentUserAllNotifications(BuildContext context) async {
//     try {
//       var header = {
//         'Content-Type': 'application/json',
//       };

//       String uri =
//           "${ApiConstants.baseUrl}${ApiConstants.getNotifications}${Provider.of<CurrentUserProvider>(context, listen: false).user?.userId}";

//       print(uri);
//       http.Response response = await http.get(Uri.parse(uri), headers: header);

//       print(response.body);
//       if (response.statusCode == 200) {
//         var data = jsonDecode(response.body);
//         if (data != null && data['data'] != null) {
//           List<dynamic> notificationList = data['data']['rows'];
//           print("Notification response body: ${response.body}");
//           print("Notification length: ${notificationList.length}");
// //jus print id of first notification
//           print("Notification isRead: ${notificationList[0]['isRead']}");
//           List<NotificationViewModel> feedList = [];
//           for (int i = 0; i < notificationList.length; i++) {
//             feedList.add(NotificationViewModel.fromJson(notificationList[i]));
//             print("Notification feedlist isReads");
//             print("Notification feedlist isReads: ${feedList[i].isRead}");
//           }

//           print(feedList.length);
//           Provider.of<NotificationProvider>(context, listen: false)
//               .updateNotifications(feedList);
//           print("Notification feedlist: ${feedList}");

//           EasyLoading.dismiss();
//           return true;
//         } else {
//           print('Data or notification list is null');
//           return false;
//         }
//       } else {
//         EasyLoading.showError(response.statusCode.toString());
//         return false;
//       }
//     } catch (error) {
//       print('Error: $error');
//       EasyLoading.showError('Failed to fetch notification data');
//       return false;
//     }
//   }

//   Future<void> readNotification(int notificationId, context) async {
//     String url = '${ApiConstants.baseUrl}/notification';

//     Map<String, dynamic> requestBody = {
//       'id': notificationId.toString(), // Convert notificationId to string
//     };
//     print('Read Noti Request body: $requestBody');

//     // Send POST request
//     http.Response response = await http.put(
//       Uri.parse(url),
//       body: jsonEncode(requestBody), // Encode the requestBody as JSON
//       headers: {
//         'Content-Type': 'application/json', // Set content type to JSON
//       },
//     );
//     if (response.statusCode == 200) {
//       // Profile updated successfully
//       //print body
//       print('Read Noti Response body: ${response.body}');
//       // You can navigate to a success screen or perform other actions here
//     } else {
//       // Profile update failed
//       print('Error reading noti. Status code: ${response.statusCode}');
//     }
//   }
// }
