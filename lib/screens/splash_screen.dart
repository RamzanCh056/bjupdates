import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../notification_services/notification_services.dart';
import '../services/navigation_service.dart';
import 'auth_screen/login_screen.dart';
import 'bottom_nav_bar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // NotificationServices notificationServices = NotificationServices();
  @override
  void initState() {
    super.initState();
    _goNext();
  }

  void _goNext() {
    // show logo for 1s
    Timer(const Duration(seconds: 1), () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavBar()),
          (_) => false,
        );
        // Check for pending notification navigation after navigation completes
        Future.delayed(const Duration(seconds: 1), () {
          NavigationService.checkPendingNavigation();
        });
      } else {
        // not signed in
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen(selectedRole: '',)),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: SizedBox(
            height: 200,
            width: 200,
            child: Image.asset("assets/images/logo.png", fit: BoxFit.cover),
          ),
        ),
      );
  }
}
