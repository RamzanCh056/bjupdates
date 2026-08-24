import 'package:beatjerky/notification_services/build_notification_widget.dart';
import 'package:beatjerky/screens/premium_plans/services/premium_plan_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MembershipHistoryScreen extends StatelessWidget {
  const MembershipHistoryScreen({super.key});

  static const Color _primaryPurple = Color(0xFF9B42F5);
  static const Color _cardBg = Color(0xFF1B1B1B);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          backgroundColor: Colors.black,
          title: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  "Premium Subscription",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              buildNotificationIcon(),
            ],
          ),
        ),
        body: const Center(
          child: Text(
            'Please login to view membership history.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final historyStream = FirebaseFirestore.instance
        .collection('usersData')
        .doc(uid)
        .collection('planHistory')
        .orderBy('planStartDate', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        backgroundColor: Colors.black,
        title: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                "Premium Subscription",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            buildNotificationIcon(),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: historyStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryPurple),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Membership History",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No membership history yet.",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Membership History",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final planLabel =
                          (data['planLabel'] as String?) ?? 'Premium Plan';
                          final planKey = (data['plan'] as String?) ?? ''; 
                      final amount = (data['amount'] as num?)?.toDouble() ?? 0;
                      final currency = (data['currency'] as String?) ?? 'USD';

                      final startTs = data['planStartDate'] as Timestamp?;
                      final endTs = data['planEndDate'] as Timestamp?;
                      final statusStr = (data['status'] as String?) ?? '';

                      final startDate = startTs?.toDate();
                      final endDate = endTs?.toDate();

                      final now = DateTime.now();
                      final isActive = endDate != null && now.isBefore(endDate);

                      final status = statusStr.isNotEmpty
                          ? statusStr
                          : (isActive ? 'active' : 'expired');

                      // show buttons only for the latest active plan (first card)
                      final showActions = index == 0 && status == 'active';

                      return _PlanHistoryCard(
                        planKey: planKey,
                        planLabel: planLabel,
                        amountText:
                            '${_currencySymbol(currency)}${amount.toStringAsFixed(2)}',
                        startText: _formatDate(startDate),
                        endText: _formatDate(endDate),
                        status: status,
                        showActions: showActions,
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date); // e.g. 11 Nov 2025
  }

  static String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return ''; // you can adjust
    }
  }
}

class _PlanHistoryCard extends StatelessWidget {
  final String planKey;
  final String planLabel;
  final String amountText;
  final String startText;
  final String endText;
  final String status; // 'active', 'expired', 'cancelled', etc.
  final bool showActions;

  const _PlanHistoryCard({
    required this.planLabel,
    required this.amountText,
    required this.startText,
    required this.endText,
    required this.status,
    required this.showActions, required this.planKey,
  });

  Color get _statusBgColor {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green.withOpacity(0.18);
      case 'cancelled':
        return Colors.red.withOpacity(0.18);
      default:
        return Colors.white12;
    }
  }

  Color get _statusTextColor {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  String get _statusLabel {
    final s = status.toLowerCase();
    if (s.isEmpty) return 'Unknown';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final premiumServices = PremiumPlaneServices();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MembershipHistoryScreen._cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan name
          Text(
            planLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Plan / Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LabelValue(label: "Plan", value: planLabel),
              _LabelValue(label: "Amount", value: amountText, alignRight: true),
            ],
          ),
          const SizedBox(height: 12),

          // Start / Expiry
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LabelValue(label: "Start Date", value: startText),
              _LabelValue(
                label: "Expiry Date",
                value: endText,
                alignRight: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status
          const Text(
            "Status",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusBgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusTextColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          if (showActions) ...[
            const SizedBox(height: 18),

            // Upgrade / Renew buttons
            // Row(
            //   children: [
            //     Expanded(
            //       child: OutlinedButton(
            //         onPressed: () {
            //           premiumServices.upgradeToYearly(context: context);
            //         },
            //         style: OutlinedButton.styleFrom(
            //           side: const BorderSide(
            //             color: MembershipHistoryScreen._primaryPurple,
            //             width: 1.3,
            //           ),
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(30),
            //           ),
            //           padding: const EdgeInsets.symmetric(vertical: 12),
            //         ),
            //         child: const Text(
            //           "Upgrade to Yearly",
            //           style: TextStyle(
            //             color: MembershipHistoryScreen._primaryPurple,
            //             fontWeight: FontWeight.w600,
            //             fontSize: 13,
            //           ),
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 10),
            //     Expanded(
            //       child: ElevatedButton(
            //         onPressed: () {
            //           premiumServices.renewPlan(
            //             plan: planKey,
            //             context: context,
            //           );
            //         },
            //         style: ElevatedButton.styleFrom(
            //           backgroundColor: MembershipHistoryScreen._primaryPurple,
            //           shape: RoundedRectangleBorder(
            //             borderRadius: BorderRadius.circular(30),
            //           ),
            //           padding: const EdgeInsets.symmetric(vertical: 12),
            //           elevation: 0,
            //         ),
            //         child: const Text(
            //           "Renew Plan",
            //           style: TextStyle(
            //             color: Colors.white,
            //             fontWeight: FontWeight.w600,
            //             fontSize: 13,
            //           ),
            //         ),
            //       ),
            //     ),
            //   ],
            // ),

             SizedBox(
              width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      premiumServices.renewPlan(
                        plan: planKey,
                        context: context,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MembershipHistoryScreen._primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text(
                      "Renew Plan",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: 10),

            // Cancel Subscription
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  showCancelSubscriptionDialog(
                    context,
                    onConfirm: () async {
                      await cancelCurrentPlan();

                      if (context.mounted) {
                        Navigator.of(context).pop(); // close dialog
                        AppToast.show('Your subscription has been cancelled.', isError: true);
                      }
                    },
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white, width: 1.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  "Cancel Subscription",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final bool alignRight;

  const _LabelValue({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final textAlign = alignRight ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: textAlign,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: textAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

Future<void> cancelCurrentPlan() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  final firestore = FirebaseFirestore.instance;
  final userRef = firestore.collection('usersData').doc(uid);

  // 1️⃣ Get the user's active plan info
  final userDoc = await userRef.get();
  if (!userDoc.exists) return;

  final userData = userDoc.data() as Map<String, dynamic>;
  final String? plan = userData['paidPlan'] as String?;

  // 2️⃣ If no active plan, do nothing
  if (plan == null || plan == 'none') return;

  // 3️⃣ Update user's current status
  await userRef.update({
    "isPaid": false,
    "paidPlan": "none",
    "planStartDate": null,
    "planEndDate": null,
    "expiryReminderSent": false,
  });

  // 4️⃣ Find the last (most recent) history record
  final historyQuery = await userRef
      .collection('planHistory')
      .orderBy('planStartDate', descending: true)
      .limit(1)
      .get();

  if (historyQuery.docs.isNotEmpty) {
    final latestDoc = historyQuery.docs.first;
    await latestDoc.reference.update({
      "status": "cancelled",
      "cancelledAt": FieldValue.serverTimestamp(),
    });
  }

  debugPrint("✅ Subscription cancelled successfully");
}

Future<void> showCancelSubscriptionDialog(
  BuildContext context, {
  required VoidCallback onConfirm,
}) {
  const primaryPurple = Color(0xFF9B42F5);

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Color(0xFF212121),
        insetPadding: EdgeInsets.all(15),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // icon
                  Container(
                    width: 46,
                    height: 46,
                    padding: EdgeInsets.only(bottom: 6),
                    decoration: const BoxDecoration(
                      color: primaryPurple,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Cancel Subscription?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'If you cancel now, you’ll lose access to all premium features at the end of your current billing period.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.white70,
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Keep Subscription',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            onConfirm(); // run your cancel logic
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Cancel Plan',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 25, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      );
    },
  );
}
