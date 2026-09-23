import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/account_status_service.dart';
import '../../utils/color.dart';
import '../auth_screen/login_screen.dart';

/// Full-screen block shown to a suspended or banned user. The user cannot
/// navigate past it — only log out — and on re-login they land here again
/// until an admin reinstates the account.
class BlockedScreen extends StatelessWidget {
  final AccountStatusModel status;

  const BlockedScreen({super.key, required this.status});

  Future<void> _logout() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance
            .collection('usersData')
            .doc(uid)
            .update({'fcmToken': FieldValue.delete()});
      }
    } catch (_) {
      // ignore — logging out regardless
    }
    await FirebaseAuth.instance.signOut();
    Get.offAll(() => const LoginScreen(selectedRole: ''));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: darkBackgroundPrimary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: redColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: redColor.withValues(alpha: 0.5)),
                  ),
                  child: Icon(
                    status.isBanned ? Icons.block : Icons.pause_circle_outline,
                    color: redColor,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  status.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  status.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (status.isSuspended && status.until != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Suspended until ${_formatUntil(status.until!)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'If you believe this is a mistake, please contact BeatJerky support.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextButton(
                      onPressed: _logout,
                      child: const Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatUntil(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
