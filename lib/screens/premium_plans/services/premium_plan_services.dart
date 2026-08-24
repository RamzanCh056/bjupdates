import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:beatjerky/stripe_payment/stripe_payment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as StripePkg;

class PremiumPlaneServices {
  Future<void> startStripeFlow({
    required int priceCents,
    required String plan,
    required double amount,
    required BuildContext context, required Null Function() onSuccess,
  }) async {
    final stripeServices = StripeServices();
    try {
      // Create a minimal payment sheet
      final pi = await stripeServices.createPaymentIntent(
        priceCents.toString(),
      );
      await StripePkg.Stripe.instance.initPaymentSheet(
        paymentSheetParameters: StripePkg.SetupPaymentSheetParameters(
          paymentIntentClientSecret: pi['client_secret'],
          customFlow: true,
          merchantDisplayName: 'BeatJerky',
        ),
      );
      await StripePkg.Stripe.instance.presentPaymentSheet();

      await savePlanToFirebase(
        plan: plan,
        amount: amount,
      );

      final planText = _planLabel(plan);

      final message = '$planText plan activated successfully!';

      AppToast.show(message);
    } catch (e) {
      AppToast.show('Payment failed: $e', isError: true);
    }
  }

  Future<void> savePlanToFirebase({
    required String plan, // 'oneday' | 'monthly' | 'yearly'
    required double amount, // 2.0, 19.0, 199.99
    String currency = 'USD',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    late DateTime endDate;
    late String planLabel;

    if (plan == 'oneday') {
      endDate = now.add(const Duration(days: 1));
      planLabel = 'One Day Premium';
    } else if (plan == 'monthly') {
      endDate = now.add(const Duration(days: 30));
      planLabel = 'Monthly Premium';
    } else if (plan == 'yearly') {
      endDate = now.add(const Duration(days: 365));
      planLabel = 'Yearly Premium';
    } else {
      // unknown plan
      return;
    }

    final userRef = FirebaseFirestore.instance.collection('usersData').doc(uid);
    final historyRef = userRef.collection('planHistory');

    // 1️⃣ Update current plan on user doc
    await userRef.update({
      "isPaid": true,
      "paidPlan": plan,
      "paidAt": FieldValue.serverTimestamp(),
      "planStartDate": now,
      "planEndDate": endDate,
      "expiryReminderSent": false, // for your reminder logic
    });

    final latestSnap = await historyRef
        .orderBy('planStartDate', descending: true)
        .limit(1)
        .get();

    final historyData = {
      "plan": plan,
      "planLabel": planLabel,
      "amount": amount,
      "currency": currency,
      "status": "active",
      "planStartDate": now,
      "planEndDate": endDate,
      "updatedAt": FieldValue.serverTimestamp(),
    };

    if (latestSnap.docs.isNotEmpty) {
      // 🔁 RENEW / UPGRADE → update same history document
      await latestSnap.docs.first.reference.update(historyData);
    } else {
      // 🆕 FIRST PURCHASE → create history doc
      await historyRef.add({
        ...historyData,
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> renewPlan({
    required String plan, // 'oneday' | 'monthly' | 'yearly'
    required BuildContext context,
  }) async {
    final priceCents = _planPriceCents[plan];
    final amount = _planAmounts[plan];

    if (priceCents == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unknown plan, cannot renew.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await startStripeFlow(
      priceCents: priceCents,
      plan: plan,
      amount: amount,
      context: context, onSuccess: () {  },
    );
  }

  // ⬆️ UPGRADE TO YEARLY LOGIC
  Future<void> upgradeToYearly({required BuildContext context}) async {
    const plan = 'yearly';
    final priceCents = _planPriceCents[plan];
    final amount = _planAmounts[plan];

    if (priceCents == null || amount == null) {
      AppToast.show('Yearly plan config missing.', isError: true);
      return;
    }

    await startStripeFlow(
      priceCents: priceCents,
      plan: plan,
      amount: amount,
      context: context, onSuccess: () {  },
    );
  }

  // 1 day before expiry
  static const int _reminderHoursBefore = 24;

  static Future<void> checkPlanExpiration(DocumentSnapshot doc) async {
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final planEndTs = data["planEndDate"] as Timestamp?;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (planEndTs == null || uid == null) return;

    final planEnd = planEndTs.toDate();
    final now = DateTime.now();

    final bool isPaid = data["isPaid"] == true;
    final bool reminderSent = data["expiryReminderSent"] == true;

    // ⏱ Time left
    final diff = planEnd.difference(now);

    final userRef = FirebaseFirestore.instance.collection("usersData").doc(uid);
    final historyRef = userRef.collection('planHistory');

    // 1️⃣ Plan already expired → downgrade
    if (now.isAfter(planEnd)) {
      await userRef.update({
        "isPaid": false,
        "paidPlan": "none",
        "planStartDate": null,
        "planEndDate": null,
        "expiryReminderSent": false, // reset for next plan
      });

      // update latest history entry → expired
      final latestSnap = await historyRef
          .orderBy('planStartDate', descending: true)
          .limit(1)
          .get();

      if (latestSnap.docs.isNotEmpty) {
        await latestSnap.docs.first.reference.update({
          "status": "expired",
          "expiredAt": FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    // 2️⃣ Send ONE reminder in the last 24 hours before expiry
    if (isPaid &&
        !reminderSent &&
        diff <= const Duration(hours: _reminderHoursBefore) &&
        diff > Duration.zero) {
      await _sendPlanExpiryNotification(uid: uid, planEnd: planEnd);

      await FirebaseFirestore.instance.collection("usersData").doc(uid).update({
        "expiryReminderSent": true,
      });
    }
  }

  /// 🔔 Send notification + save it in Firestore
  static Future<void> _sendPlanExpiryNotification({
    required String uid,
    required DateTime planEnd,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Get user doc to read fcmToken (like your example)
      final userDoc = await firestore.collection('usersData').doc(uid).get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;
      final firstName = userData['firstName'] ?? 'User';

      const type = 'plan_expiry';
      final message =
          'Hi $firstName, your premium plan is about to end. Renew now to keep all premium features.';
      const title = 'Your premium plan is expiring soon';
      const body = 'Your plan will expire within 24 hours. Tap to renew.';

      // 🔹 Send FCM push (reuse your trigger object here)
      if (fcmToken != null && fcmToken.isNotEmpty) {
        try {
          // ⬇️ Use the same trigger you already have in your app
          await TriggerNotificationService().sendPushNotification(
            token: fcmToken,
            title: title,
            body: body,
          );
        } catch (e) {
          debugPrint('Error sending plan expiry push to $uid: $e');
        }
      }

      // 🔹 Save notification document (same style as your song notification)
      await firestore
          .collection('notifications')
          .doc(uid)
          .collection('userNotifications')
          .add({
            'type': type,
            'fromUserId': 'system',
            'fromUserName': 'System',
            'timestamp': FieldValue.serverTimestamp(),
            'message': message,
            'isRead': false,
          });

      debugPrint('Plan expiry notification sent to $uid');
    } catch (e) {
      debugPrint('Error in _sendPlanExpiryNotification: $e');
    }
  }

  // 🔹 Map your plans to Stripe price (in cents) – adjust to your real prices
  static const Map<String, int> _planPriceCents = {
    'oneday': 200, // $2.00
    'monthly': 1900, // $19.00
    'yearly': 19999, // $199.99
  };

  // 🔹 Map your plans to amount saved in Firestore
  static const Map<String, double> _planAmounts = {
    'oneday': 2.0,
    'monthly': 19.0,
    'yearly': 199.99,
  };

  String _planLabel(String plan) {
    switch (plan) {
      case 'oneday':
        return "One-Day";
      case 'monthly':
        return "Monthly";
      case 'yearly':
        return "Yearly";
      default:
        return plan;
    }
  }
}
