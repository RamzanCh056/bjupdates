import 'package:beatjerky/Stripe/premium_subscription_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionGuard extends StatefulWidget {
  final String userEmail;
  final Widget child; // Screen to show if paid or in trial
  final Future<void> Function(BuildContext context, String email) onSubscribe;

  const SubscriptionGuard({
    Key? key,
    required this.userEmail,
    required this.child,
    required this.onSubscribe,
  }) : super(key: key);

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  bool _isSubscribing = false;
  late Future<Map<String, dynamic>?> _subscriptionData;
  bool _hasShownExpiredDialog = false; // Flag to prevent multiple dialogs

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  void _loadSubscriptionData() {
    _subscriptionData = FirebaseFirestore.instance
        .collection('usersData')
        .where('email', isEqualTo: widget.userEmail)
        .get()
        .then((querySnapshot) {
          if (querySnapshot.docs.isNotEmpty) {
            return querySnapshot.docs.first.data();
          }
          return null;
        });
  }

  // Check if user is in trial period
  bool _isInTrialPeriod(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // First check if subscription is paid
    if (userData['subscription'] == "paid") return false;

    // Check if user has trial end date
    if (userData.containsKey('trialEndDate')) {
      final trialEnd = (userData['trialEndDate'] as Timestamp).toDate();
      final now = DateTime.now();

      // User is in trial if current date is before trial end date
      return now.isBefore(trialEnd);
    }

    // Fallback to trialStartDate check if trialEndDate doesn't exist
    if (userData.containsKey('trialStartDate')) {
      final trialStart = (userData['trialStartDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceTrialStart = now.difference(trialStart).inDays;
      return daysSinceTrialStart < 7;
    }

    return false;
  }

  // Get remaining trial days
  int _getRemainingTrialDays(Map<String, dynamic>? userData) {
    if (userData == null) return 0;

    // Use trialEndDate if available
    if (userData.containsKey('trialEndDate')) {
      final trialEnd = (userData['trialEndDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final remainingDays = trialEnd.difference(now).inDays;
      return remainingDays > 0 ? remainingDays : 0;
    }

    // Fallback to trialStartDate calculation
    if (userData.containsKey('trialStartDate')) {
      final trialStart = (userData['trialStartDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceTrialStart = now.difference(trialStart).inDays;
      return 7 - daysSinceTrialStart;
    }

    return 0;
  }

  // Check if trial is expired
  bool _isTrialExpired(Map<String, dynamic>? userData) {
    if (userData == null) return false;

    // Don't check if already paid
    if (userData['subscription'] == "paid") return false;

    // Check using trialEndDate first
    if (userData.containsKey('trialEndDate')) {
      final trialEnd = (userData['trialEndDate'] as Timestamp).toDate();
      final now = DateTime.now();
      return now.isAfter(trialEnd) || now.isAtSameMomentAs(trialEnd);
    }
    // Fallback to trialStartDate calculation
    else if (userData.containsKey('trialStartDate')) {
      final trialStart = (userData['trialStartDate'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceTrialStart = now.difference(trialStart).inDays;
      return daysSinceTrialStart >= 7;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _subscriptionData,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadSubscriptionData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final userData = snapshot.data;

        // Check if user is paid
        if (userData?['subscription'] == "paid") {
          return widget.child;
        }

        // Check if user is in trial period
        if (_isInTrialPeriod(userData)) {
          final remainingDays = _getRemainingTrialDays(userData);
          final height = MediaQuery.of(context).size.height;

          // Show trial banner on the child screen (constrain Stack so child gets bounded size)
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                Positioned.fill(child: widget.child),
                // Trial banner at the top
                Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B42F5), Color(0xFFB366FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9B42F5).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Trial Period: $remainingDays day${remainingDays == 1 ? '' : 's'} left',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            ),
          );
        }

        // If Not Paid and trial expired or no trial → Show subscription UI
        // Constrain height so Scaffold gets bounded size when inside scrollable
        final height = MediaQuery.of(context).size.height;
        return Builder(
          builder: (context) {
            return SizedBox(
              height: height,
              child: PremiumSubscriptionScreen(
                showAsGuard: true,
                guardedChild: widget.child,
                onSubscribe: widget.onSubscribe,
              ),
            );
          },
        );
      },
    );
  }
}
