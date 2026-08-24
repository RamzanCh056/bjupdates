import 'dart:developer';
import 'package:beatjerky/notification_services/email_service.dart';
import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:beatjerky/screens/order_screen/models/order_model.dart';
import 'package:beatjerky/screens/order_screen/services/order_services.dart';
import 'package:beatjerky/screens/order_screen/widgets/order_tile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';

class SalesTab extends StatelessWidget {
  final OrderService orderService;
  const SalesTab({super.key, required this.orderService});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    const primaryColor = Color(0xFFBB86FC);

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.salesStream(userId),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Color(0xFFBB86FC),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Error Loading Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '${snapshot.error}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        if (!snapshot.hasData)
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
              strokeWidth: 3,
            ),
          );
        final orders = snapshot.data!;
        if (orders.isEmpty)
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_outlined,
                    size: 64,
                    color: Color(0xFFBB86FC)
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No Sales Yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your sales history will appear here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: OrderTile(
                order: orders[i],
                isSellerView: true,
                onMarkAsDispatched: () async {
                  if (orders[i].status == 'pending') {
                    await orderService.markAsDispatched(orders[i].orderId);
                    await _sendDispatchedNotification(
                      buyerId: order.buyerId,
                      sellerName: order.sellerName,
                      productName: order.productName,
                    );
                    AppToast.show('Order marked as dispatched and buyer notified.');
                  } else {
                    AppToast.show('Cannot dispatch unless pending', isError: true);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  /// 🔔 Helper: Notify buyer when seller marks as dispatched
  Future<void> _sendDispatchedNotification({
    required String buyerId,
    required String sellerName,
    required String productName,
  }) async {
    try {
      final title = "📦 Your Order Has Been Dispatched!";
      final body =
          "$sellerName has dispatched your order for $productName. It’s on the way!";

      final _firestore = FirebaseFirestore.instance;

      // Fetch buyer FCM token
      final buyerDoc = await _firestore
          .collection("usersData")
          .doc(buyerId)
          .get();
      if (!buyerDoc.exists) {
        log("⚠️ Buyer document not found for ID: $buyerId");
        return;
      }

      final buyerData = buyerDoc.data();
      final buyerFcmToken = buyerData?['fcmToken'] ?? "";
      final buyerEmail = buyerData?['email'] ?? "";
      final buyerName = buyerData?['firstName'] ?? "Customer";

      // Send push notification
      if (buyerFcmToken.isNotEmpty) {
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: buyerFcmToken,
          title: title,
          body: body,
        );
      } else {
        log("⚠️ No FCM token found for buyer $buyerId");
      }

      // Save notification to Firestore
      final notificationData = {
        'type': 'dispatched',
        'fromUserId': FirebaseAuth.instance.currentUser!.uid,
        'fromUserName': sellerName,
        'timestamp': FieldValue.serverTimestamp(),
        'message': body,
        'isRead': false,
      };

      await _firestore
          .collection('notifications')
          .doc(buyerId)
          .collection('userNotifications')
          .add(notificationData);

      if (buyerEmail.isNotEmpty) {
        final emailService = EmailService();

        final emailBody =
            '''
        <h2>Good news, $buyerName! 🎉</h2>
        <p>Your order for <strong>$productName</strong> has just been dispatched by <b>$sellerName</b>.</p>
        <p>It’s now on its way and will reach you soon.</p>
        <br>
        <p>Thank you for shopping with <b>BeatJerky</b>!</p>
        <p><i>— The BeatJerky Team</i></p>
      ''';

        await emailService.sendEmail(
          to: buyerEmail,
          subject: "📦 Your Order Is On The Way!",
          body: emailBody,
        );

        log("📧 Dispatch email sent successfully to $buyerEmail");
      } else {
        log("⚠️ No email found for buyer $buyerId");
      }
    } catch (e, stack) {
      log("❌ Error sending dispatched notification: $e");
      log(stack.toString());
    }
  }
}
