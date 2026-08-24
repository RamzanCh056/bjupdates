import 'package:beatjerky/screens/notification/notification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Widget buildNotificationIcon() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(currentUser.uid)
          .collection('userNotifications')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = snapshot.data?.docs.length ?? 0;

        return Stack(
          children: [
            Badge(
              label: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              offset: const Offset(-8, 5),
              isLabelVisible: unreadCount > 0,
              backgroundColor: const Color(0xffED2024),
              child: IconButton(
                onPressed: () {
                  // Navigate to notifications page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotificationScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }