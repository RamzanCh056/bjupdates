import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:beatjerky/utils/name_utils.dart';
import 'new_reels.dart';
import 'profile_screen.dart';

/// Opens the profile for [userId]. If it's the current user, opens [ProfileScreen] (with Edit profile).
/// Otherwise opens [ProfileScreen] for that user (same layout, no Edit profile).
void openUserProfile(BuildContext context, String userId) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProfileScreen(userId: userId == currentUid ? null : userId),
    ),
  );
}

class ViewUserProfileScreen extends StatefulWidget {
  final String userId;

  const ViewUserProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<ViewUserProfileScreen> createState() => _ViewUserProfileScreenState();
}

class _ViewUserProfileScreenState extends State<ViewUserProfileScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String? _firstName;
  String? _secondName;
  String? _profileImage;
  bool _isPaid = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final doc = await _firestore.collection('usersData').doc(widget.userId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _firstName = data['firstName'] as String?;
          _secondName = data['secondName'] as String?;
          _profileImage = data['profileImage'] as String?;
          _isPaid = (data['isPaid'] ?? false) as bool;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openReels() async {
    final snapshot = await _firestore
        .collection('reels')
        .where('userId', isEqualTo: widget.userId)
        .orderBy('timestamp', descending: true)
        .get();
    if (!mounted) return;
    final docs = snapshot.docs;
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No reels yet'),
          backgroundColor: Colors.grey[800],
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReelsScreen(
          showBackButton: true,
          reelsList: docs,
          initialReelIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: purpleAccent, strokeWidth: 3),
                  const SizedBox(height: 16),
                  Text(
                    'Loading…',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: darkBackgroundTertiary,
                    backgroundImage: (_profileImage != null && _profileImage!.isNotEmpty)
                        ? NetworkImage(_profileImage!)
                        : null,
                    child: (_profileImage == null || _profileImage!.isEmpty)
                        ? const Icon(Icons.person, color: Colors.white54, size: 56)
                        : null,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        NameUtils.getDisplayNameSafe(_firstName, _secondName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_isPaid) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle_rounded, color: Colors.blue[400], size: 22),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openReels,
                      icon: const Icon(Icons.video_library_rounded, size: 22),
                      label: const Text('View reels'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purpleAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
