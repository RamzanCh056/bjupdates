import 'package:beatjerky/screens/premium_plans/services/premium_plan_services.dart';
import 'package:beatjerky/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/color.dart';
import 'New Feed/new_feed.dart';
import 'home1/home1.dart';
import 'leaderboard_screen.dart';
import 'new_reels.dart';
import 'bjai_screen.dart';
import 'studio_screen.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({Key? key}) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  Stream<DocumentSnapshot>? _planStream;

  void initState() {
    super.initState();
    _startPlanExpirationStream();
  }

  void _startPlanExpirationStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  _planStream = FirebaseFirestore.instance
      .collection("usersData")
      .doc(uid)
      .snapshots();

  _planStream!.listen((doc) {
    if (!doc.exists) return;
    PremiumPlaneServices.checkPlanExpiration(doc);
  });
}

  int _currentIndex = 0;
  List<dynamic> get _pages => [
    const Home1(),
    const StudioScreen(),
    const BJAI(),
    NewFeedScreen(),
    const ReelsScreen(),
    const LeaderboardScreen(),
    const ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Color(0xFF0A0E27),
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 8,
          unselectedFontSize: 7,
          currentIndex: _currentIndex,
          selectedItemColor: recntsColor,
          unselectedItemColor: Colors.grey,
          onTap: (v) {
            setState(() {
              _currentIndex = v;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.graphic_eq_rounded),
              label: 'Studio',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'BJAI'),
            BottomNavigationBarItem(icon: Icon(Icons.feed), label: 'Feed'),
            BottomNavigationBarItem(
              icon: Icon(Icons.play_circle),
              label: 'Video',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.emoji_events),
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
        body: _pages[_currentIndex],
      );
  }
}