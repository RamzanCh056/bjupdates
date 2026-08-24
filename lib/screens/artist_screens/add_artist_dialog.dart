import 'dart:io';
import 'dart:developer';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/Dialog/show_premium_unlock_dialog.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddArtistDialog extends StatefulWidget {
  const AddArtistDialog({Key? key}) : super(key: key);

  @override
  State<AddArtistDialog> createState() => _AddArtistDialogState();
}

class _AddArtistDialogState extends State<AddArtistDialog> {
  final _picker = ImagePicker();
  File? _image;
  final _nameCtrl = TextEditingController();
  final _bandCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  bool _submitting = false;

  static const String _cloudFunctionUrl =
      'https://sendbeatjerkyartistnotification-6j4mf27zeq-uc.a.run.app';

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (xfile != null) {
      setState(() => _image = File(xfile.path));
    }
  }

  Future<void> _sendArtistNotification({
    required String artistName,
    String? bandName,
    String? about,
  }) async {
    log('📤 Calling cloud function at: $_cloudFunctionUrl');

    // Format the artist data with event name as required by the cloud function
    final Map<String, dynamic> requestBody = {
      'eventName': '$artistName',
      'eventDescription': about ?? 'A new artist has joined BeatJerky!',
      'eventLocation': bandName?.isNotEmpty == true
          ? bandName!
          : 'BeatJerky Platform',
      'type': 'artist',
      'artistName': artistName,
      'bandName': bandName ?? '',
      'about': about ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    };

    log('📤 Request body: ${jsonEncode(requestBody)}');

    try {
      final response = await http
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              log('❌ Cloud function request timeout');
              throw Exception('Request timeout');
            },
          );

      log('📥 Cloud function response status: ${response.statusCode}');
      log('📥 Cloud function response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        log(
          '✅ Artist notification sent via cloud function: ${data['statistics'] ?? 'success'}',
        );

        // Show success toast for notification
        if (mounted) {
          AppToast.show('Artist added and notifications sent!', isError: false);
        }
      } else {
        log(
          '❌ Cloud function returned ${response.statusCode}: ${response.body}',
        );

        // Parse error message
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            log('❌ Cloud function error: ${errorData['error']}');
          }
        } catch (e) {
          log('❌ Could not parse error response');
        }

        // Show warning but don't fail the artist creation
        if (mounted) {
          AppToast.show('Artist added but notification failed', isError: true);
        }
      }
    } catch (e) {
      log('❌ Error calling sendArtistNotification cloud function: $e');
      // Don't throw the error - artist was already created successfully
      if (mounted) {
        AppToast.show(
          'Artist added but notification service unavailable',
          isError: true,
        );
      }
    }
  }

  Future<void> _submit() async {
    final userStatus = context.read<UserStatusProvider>();
    if (!userStatus.isArtist) {
      AppToast.show(
        'Only Artists can create and manage artist profiles',
        isError: true,
      );
      return;
    }
    final bool isPaid = userStatus.isPaid;
    final int currentPoints = userStatus.totalPoints;
    const int artistCost = 30;

    // 1️⃣ Basic validation
    if (_nameCtrl.text.isEmpty ||
        _bandCtrl.text.isEmpty ||
        _aboutCtrl.text.isEmpty ||
        _image == null) {
      AppToast.show('All fields and a picture are required', isError: true);
      return;
    }

    // 2️⃣ Check points for non-paid users
   

    // 3️⃣ Proceed with submit
    setState(() => _submitting = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final id = const Uuid().v4();

      // upload image
      final ref = FirebaseStorage.instance.ref().child('artists/$id.jpg');
      await ref.putFile(_image!);
      final url = await ref.getDownloadURL();

      // save artist
      await FirebaseFirestore.instance.collection('artists').doc(id).set({
        'name': _nameCtrl.text.trim(),
        'bandName': _bandCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        'imageUrl': url,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4️⃣ If user is not paid → deduct 30 points after successful add
      if (!isPaid) {
        final rewardRef = FirebaseFirestore.instance
            .collection('userRewards')
            .doc(uid);

        await FirebaseFirestore.instance.runTransaction((txn) async {
          final snap = await txn.get(rewardRef);
          if (!snap.exists) return;

          final data = snap.data() as Map<String, dynamic>;
          final current = (data['totalPoints'] ?? 0) as num;
          final newPoints = current - artistCost;

          // prevent going negative
          if (newPoints < 0) return;

          txn.update(rewardRef, {'totalPoints': newPoints});
        });

        // Update local provider
   
      }

      // 5️⃣ Send notification about new artist (don't await to not block UI)
      _sendArtistNotification(
            artistName: _nameCtrl.text.trim(),
            bandName: _bandCtrl.text.trim(),
            about: _aboutCtrl.text.trim(),
          )
          .then((_) {
            log('✅ Notification process completed');
          })
          .catchError((error) {
            log('❌ Notification error: $error');
          });

      // Close dialog after successful addition
      if (mounted) {
        Navigator.of(context).pop();
        AppToast.show('Artist added successfully!', isError: false);
      }
    } catch (e) {
      log('❌ Error adding artist: $e');
      if (mounted) {
        AppToast.show('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: darkBackgroundPrimary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add New Artist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180,
                        width: 185,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: accent.withOpacity(0.2),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _image == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: accent.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate,
                                      color: accent,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Tap to Add Artist Picture',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Recommended: Square image',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: [
                                    Image.file(
                                      _image!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Text fields
                    _buildDarkTextField(
                      _nameCtrl,
                      'Artist Name',
                      Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkTextField(
                      _bandCtrl,
                      'Band Name',
                      Icons.music_note_outlined,
                    ),
                    const SizedBox(height: 16),
                    _buildDarkTextField(
                      _aboutCtrl,
                      'About the Artist',
                      Icons.info_outline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 28),

                    // Points info for non-premium users
                

                    // Submit button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_upload,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add Artist',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 15,
          ),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent.withOpacity(0.5), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bandCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }
}
