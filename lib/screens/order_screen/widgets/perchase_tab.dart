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

class PurchasesTab extends StatelessWidget {
  final OrderService orderService;
  PurchasesTab({super.key, required this.orderService});

  @override
  Widget build(BuildContext context) {
    final currentIserId = FirebaseAuth.instance.currentUser!.uid;
    const primaryColor = Color(0xFFBB86FC);

    return StreamBuilder<List<OrderModel>>(
      stream: orderService.purchasesStream(currentIserId),
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
                    Icons.shopping_bag_outlined,
                    size: 64,
                    color: Color(0xFFBB86FC),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No Purchases Yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your purchase history will appear here',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OrderTile(
                order: orders[i],
                isSellerView: false,
                onMarkAsDelivered: () async {
                  // buyer can mark as delivered only when status == dispatched
                  if (orders[i].status == 'dispatched') {
                    await orderService.markAsDelivered(orders[i].orderId);
                    await _sendDeliveredNotification(
                      sellerId: order.sellerId,
                      buyerName: order.buyerName,
                      productName: order.productName,
                    );

                    AppToast.show('Order marked as delivered and seller notified.');
                  } else {
                    AppToast.show('Cannot mark delivered unless dispatched', isError: true);
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🔔 Helper function: Notify seller when buyer marks as delivered
  Future<void> _sendDeliveredNotification({
    required String sellerId,
    required String buyerName,
    required String productName,
  }) async {
    try {
      final title = "📦 Order Delivered!";
      final body =
          "$buyerName confirmed delivery for $productName. The order is now complete.";

          final sellerDoc  = await _firestore.collection("usersData").doc(sellerId).get();
          final sellerData = sellerDoc.data();

          final sellerFcmToken = sellerData?['fcmToken']?? "";
          final sellerEmail = sellerData?['email'] ?? "";
          final sellerName = sellerData?['firstName'] ?? "Seller";

      // Send FCM Push Notification
      if (sellerFcmToken.isNotEmpty) {
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: sellerFcmToken,
          title: title,
          body: body,
        );
      }

      // Save Notification to Firestore
      if (sellerId.isNotEmpty) {
        final notificationData = {
          'type': 'delivered',
          'fromUserId': FirebaseAuth.instance.currentUser!.uid,
          'fromUserName': buyerName,
          'timestamp': FieldValue.serverTimestamp(),
          'message': body,
          'isRead': false,
        };

        await _firestore
            .collection('notifications')
            .doc(sellerId)
            .collection('userNotifications')
            .add(notificationData);
      }

      if (sellerEmail.isNotEmpty) {
      final emailService = EmailService();

      final emailBody = '''
        <h2>Hello $sellerName,</h2>
        <p>Great news! <strong>$buyerName</strong> has confirmed the delivery of <strong>$productName</strong>.</p>
        <p>The order is now complete. 🎉</p>
        <br>
        <p>Thank you for being a part of <b>BeatJerky</b>!</p>
        <p><i>— The BeatJerky Team</i></p>
      ''';

      await emailService.sendEmail(
        to: sellerEmail,
        subject: "✅ Order Delivered Successfully!",
        body: emailBody,
      );

      log("📧 Delivery confirmation email sent to $sellerEmail");
    } else {
      log("⚠️ No email found for seller $sellerId");
    }
    } catch (e) {
      log("Error sending delivered notification: $e");
    }
  }
}
