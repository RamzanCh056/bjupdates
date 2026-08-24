import 'package:beatjerky/notification_services/build_notification_widget.dart';
import 'package:beatjerky/screens/premium_plans/membership_history_screen.dart';
import 'package:beatjerky/screens/premium_plans/premium_widget/premium_plan_card.dart';
import 'package:beatjerky/screens/premium_plans/services/premium_plan_services.dart';
import 'package:beatjerky/stripe_payment/stripe_payment.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as StripePkg;

const Color _premiumPurple = Color(0xFF9B42F5);
const Color _premiumPurpleLight = Color(0xFFB366FF);
const Color _surfaceBg = darkBackgroundPrimary;
const Color _cardBg = darkBackgroundPrimary;
const Color _textMuted = Color(0xFFB0B0B0);

class PremiumSubscriptionScreen extends StatefulWidget {
  final bool showAsGuard; // Whether this is shown as a guard screen
  final Widget? guardedChild; // Child widget to show when subscribed/in trial
  final Future<void> Function(BuildContext context, String email)?
  onSubscribe; // Subscription callback

  const PremiumSubscriptionScreen({
    Key? key,
    this.showAsGuard = false,
    this.guardedChild,
    this.onSubscribe,
  }) : super(key: key);

  @override
  State<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  bool _isLoading = true;
  bool _isSubscribing = false;
  Map<String, dynamic>? _userData;
  String? _subscriptionStatus;
  bool _hasTrial = false;
  int _remainingTrialDays = 0;
  bool _isTrialExpired = false;
  DateTime? _trialEndDate;
  bool _hasShownExpiredDialog = false; // Flag to prevent multiple dialogs

  @override
  void initState() {
    super.initState();
    _checkUserSubscriptionStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when screen comes into focus
    _checkUserSubscriptionStatus();
  }

  Future<void> _checkUserSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('usersData')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final docRef = querySnapshot.docs.first.reference;

        setState(() {
          _userData = userData;
          _subscriptionStatus = userData['subscription'];
        });

        // Check subscription status
        if (userData['subscription'] == 'paid') {
          setState(() {
            _isLoading = false;
            _hasTrial = false;
            _isTrialExpired = false;
          });
          return;
        }

        // Check trial status using trialEndDate
        if (userData.containsKey('trialEndDate')) {
          final trialEnd = (userData['trialEndDate'] as Timestamp).toDate();
          final now = DateTime.now();

          setState(() {
            _trialEndDate = trialEnd;
          });

          // Check if trial is still valid
          final isInTrial = now.isBefore(trialEnd);

          if (isInTrial) {
            final remainingDays = trialEnd.difference(now).inDays;
            setState(() {
              _hasTrial = true;
              _remainingTrialDays = remainingDays;
              _isTrialExpired = false;
            });
          } else {
            setState(() {
              _hasTrial = false;
              _remainingTrialDays = 0;
              _isTrialExpired = true;
            });
          }
        }
        // Fallback to trialStartDate if trialEndDate doesn't exist
        else if (userData.containsKey('trialStartDate')) {
          final trialStart = (userData['trialStartDate'] as Timestamp).toDate();
          final now = DateTime.now();
          final daysSinceTrialStart = now.difference(trialStart).inDays;
          final remainingDays = 7 - daysSinceTrialStart;

          setState(() {
            _hasTrial = remainingDays > 0;
            _remainingTrialDays = remainingDays > 0 ? remainingDays : 0;
            _isTrialExpired = remainingDays <= 0;
          });
        }
        // No trial started yet - start one for new users
        else if (userData['subscription'] != 'paid') {
          final now = DateTime.now();
          final trialEnd = now.add(const Duration(days: 7));

          await docRef.update({
            'trialStartDate': Timestamp.fromDate(now),
            'trialEndDate': Timestamp.fromDate(trialEnd),
          });

          setState(() {
            _hasTrial = true;
            _remainingTrialDays = 7;
            _isTrialExpired = false;
            _trialEndDate = trialEnd;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubscribe() async {
    if (_isSubscribing) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to subscribe'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubscribing = true);

    try {
      // Call the onSubscribe callback if provided
      if (widget.onSubscribe != null) {
        await widget.onSubscribe!(context, user.email!);
      } else {
        // Fallback to default subscription handling
        // You can implement default payment flow here if needed
        debugPrint('No onSubscribe callback provided');
      }

      // Refresh subscription status after successful subscription
      await _checkUserSubscriptionStatus();

      // Show success message
     
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subscription failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubscribing = false);
      }
    }
  }

  String _getHeaderTitle() {
    if (_subscriptionStatus == 'paid') return 'Premium Active';
    if (_hasTrial) return 'Premium Trial';
    if (_isTrialExpired) return 'Trial Expired';
    return 'Premium';
  }

  String _getHeaderSubtitle() {
    if (_subscriptionStatus == 'paid') {
      return 'You have full access to all premium features';
    }
    if (_hasTrial) {
      return 'Enjoy $_remainingTrialDays day${_remainingTrialDays == 1 ? '' : 's'} of free access';
    }
    if (_isTrialExpired) {
      return 'Your trial has ended. Subscribe to continue';
    }
    return 'Unlock Beat Jerky without limits';
  }

  Widget _buildStatusBanner() {
    if (_subscriptionStatus == 'paid') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.withOpacity(0.15),
              Colors.green.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.green,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '✓ Premium Active - Full access unlocked',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_hasTrial) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _premiumPurple.withOpacity(0.15),
              _premiumPurpleLight.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _premiumPurple.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _premiumPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.card_giftcard,
                color: _premiumPurpleLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ $_remainingTrialDays day${_remainingTrialDays == 1 ? '' : 's'} of free trial remaining',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_trialEndDate != null)
                    Text(
                      'Trial ends: ${_formatDate(_trialEndDate!)}',
                      style: const TextStyle(color: _textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isTrialExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.withOpacity(0.15),
              Colors.orange.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.timer_off_rounded,
                color: Colors.orange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '⚠️ Trial expired - Subscribe to continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getButtonText() {
    if (_subscriptionStatus == 'paid') return 'Manage Subscription';
    if (_hasTrial) return 'Subscribe Now';
    if (_isTrialExpired) return 'Renew Subscription';
    return 'Start 7-Day Free Trial';
  }

  @override
  Widget build(BuildContext context) {
    // If loading, show loading indicator
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _surfaceBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If user is paid or in trial and this is guard mode, show the guarded child
    if (widget.showAsGuard &&
        (_subscriptionStatus == 'paid' || _hasTrial) &&
        widget.guardedChild != null) {
      // Add trial banner if in trial
      if (_hasTrial) {
        return Stack(
          children: [
            Positioned.fill(child: widget.guardedChild!),
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
                  gradient: LinearGradient(
                    colors: [_premiumPurple, _premiumPurpleLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _premiumPurple.withOpacity(0.3),
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
                      'Trial Period: $_remainingTrialDays day${_remainingTrialDays == 1 ? '' : 's'} left',
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
        );
      }

      // If paid, just show the child
      return widget.guardedChild!;
    }

    // Show subscription screen
    return Builder(
      builder: (context) {
        return Scaffold(
          backgroundColor: darkBackgroundPrimary,
          appBar: AppBar(
            automaticallyImplyLeading:
                !widget.showAsGuard, // Hide back button in guard mode
            titleSpacing: 0,
            backgroundColor: darkBackgroundPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: widget.showAsGuard
                ? null
                : IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
            centerTitle: true,
            title: Text(
              _getHeaderTitle(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Status banner
                    _buildStatusBanner(),
                    const SizedBox(height: 20),

                    // Hero section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _premiumPurple.withOpacity(0.2),
                            _premiumPurpleLight.withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _premiumPurple.withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _premiumPurple.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: _premiumPurpleLight,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  _getHeaderSubtitle(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_subscriptionStatus != 'paid') ...[
                            const SizedBox(height: 12),
                            Text(
                              _isTrialExpired
                                  ? "Your trial has ended. Subscribe to regain access to all premium features."
                                  : "Enjoy Beat Jerky without limits. No ads. No restrictions. Full creative freedom.",
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Membership History (hide for paid users in guard mode?)
                    if (_subscriptionStatus == 'paid' || !widget.showAsGuard)
                      const SizedBox(height: 28),

                    // Plan selection header (hide for paid users in guard mode?)
                    if (_subscriptionStatus != 'paid')
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Choose your plan",
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (_hasTrial)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _premiumPurple.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _premiumPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.timer_rounded,
                                    size: 14,
                                    color: _premiumPurpleLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '7-Day Trial',
                                    style: TextStyle(
                                      color: _premiumPurpleLight,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    if (_subscriptionStatus != 'paid')
                      const SizedBox(height: 12),

                    // Monthly Plan (hide for paid users in guard mode?)
                    if (_subscriptionStatus != 'paid')
                      PremiumPlanCard(
                        priceText: '\$5/Month',
                        benefits: const [
                          'Unlimited Feed Posts & Video Uploads',
                          'Access All AI Features Instantly',
                          'Add Unlimited Artists & Events',
                          'Zero Ads, Ever',
                          'Priority Access to New Features',
                        ],
                        onButtonPressed:
                            _handleSubscribe, // Direct subscription handler
                      ),

                    if (_subscriptionStatus != 'paid')
                      const SizedBox(height: 16),

                    // Info box (show different messages based on status)
                    if (_subscriptionStatus != 'paid')
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isTrialExpired
                                  ? Icons.error_outline_rounded
                                  : Icons.info_outline_rounded,
                              color: _isTrialExpired
                                  ? Colors.orange
                                  : _textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _isTrialExpired
                                    ? 'Subscribe now to regain access to all premium features.'
                                    : _hasTrial
                                    ? 'Cancel anytime before trial ends. You won\'t be charged until trial ends.'
                                    : 'New users get 7 days free. Cancel anytime before trial ends.',
                                style: TextStyle(
                                  color: _isTrialExpired
                                      ? Colors.orange
                                      : _textMuted,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),

              // Loading overlay
              if (_isLoading || _isSubscribing)
                Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Simplified SubscriptionGuard that uses the unified screen
class SubscriptionGuard extends StatelessWidget {
  final String userEmail;
  final Widget child;
  final Future<void> Function(BuildContext context, String email) onSubscribe;

  const SubscriptionGuard({
    Key? key,
    required this.userEmail,
    required this.child,
    required this.onSubscribe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PremiumSubscriptionScreen(
      showAsGuard: true,
      guardedChild: child,
      onSubscribe: onSubscribe,
    );
  }
}
