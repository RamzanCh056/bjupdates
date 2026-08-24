import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_toast.dart';
import '../utils/color.dart';

const Color _surfaceBg = darkBackgroundPrimary;
const Color _textMuted = Color(0xFFB0B0B0);

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers for text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // For toggling password visibility
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // For loading and saving states
  bool _isLoading = false;

  // Profile image
  String? _profileImage;
  File? _selectedImageFile;

  // Image picker instance
  final ImagePicker _picker = ImagePicker();



  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Method to pick profile image
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  /// Loads current user data from Firestore
  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // Not logged in, handle accordingly
        setState(() => _isLoading = false);
        return;
      }

      // Load from Firestore
      final doc = await FirebaseFirestore.instance.collection('usersData').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        _firstNameController.text = data['firstName'] ?? '';
        _lastNameController.text = data['secondName'] ?? '';
        _profileImage = data['profileImage'];
        _bioController.text = data['bio']?.toString() ?? '';
      }

      // Also load email from FirebaseAuth
      _emailController.text = user.email ?? '';
    } catch (e) {
      debugPrint('Error loading user data: $e');
      // Show some error to user, if needed
    }

    setState(() => _isLoading = false);
  }

  /// Saves the updated profile data
  Future<void> _saveProfile() async {
    final oldPassword = _oldPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword != confirmPassword) {
      _showMessage('New passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showMessage('No user found');
        return;
      }

      // 1) Re-authenticate with old password if user is updating email or password
      if (oldPassword.isNotEmpty && (newPassword.isNotEmpty || _emailController.text.trim() != user.email)) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: oldPassword,
        );
        await user.reauthenticateWithCredential(cred);
      }

      // 2) Update email (if changed)
      final newEmail = _emailController.text.trim();
      if (newEmail.isNotEmpty && newEmail != user.email) {
        await user.updateEmail(newEmail);
      }

      // 3) Upload profile image if selected
      String? newProfileImageUrl = _profileImage;
      if (_selectedImageFile != null) {
        EasyLoading.show(status: 'Uploading image...');
        
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');

        await storageRef.putFile(_selectedImageFile!);
        newProfileImageUrl = await storageRef.getDownloadURL();
        EasyLoading.showSuccess('Image Uploaded!');
      }

      // 3) Update password (if provided)
      if (newPassword.isNotEmpty) {
        await user.updatePassword(newPassword);
      }

      // 4) Update Firestore data (firstName, secondName, bio)
      await FirebaseFirestore.instance.collection('usersData').doc(user.uid).update({
        'firstName': _firstNameController.text.trim(),
        'secondName': _lastNameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (newProfileImageUrl != null) 'profileImage': newProfileImageUrl,
      });

      _showMessage('Profile updated successfully!');
      Navigator.pop(context); // Return to previous screen (optional)
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth Error: $e');
      _showMessage(e.message ?? 'Error updating profile');
    } catch (e) {
      debugPrint('General Error: $e');
      _showMessage('Something went wrong');
    } finally {
      EasyLoading.dismiss();
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    AppToast.show(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(purpleAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading…',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              child: Column(
                children: [
                  // Profile photo section
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickImage,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: appGradient,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: darkBackgroundTertiary,
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: _selectedImageFile != null
                                      ? Image.file(
                                          _selectedImageFile!,
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                        )
                                      : _profileImage != null && _profileImage!.isNotEmpty
                                          ? Image.network(
                                              _profileImage!,
                                              width: 110,
                                              height: 110,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Icon(
                                                Icons.person_rounded,
                                                color: Colors.white.withValues(alpha: 0.5),
                                                size: 48,
                                              ),
                                            )
                                          : Icon(
                                              Icons.person_rounded,
                                              color: Colors.white.withValues(alpha: 0.5),
                                              size: 52,
                                            ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: appGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: darkBackgroundPrimary, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Change photo',
                          style: TextStyle(
                            color: purpleAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Personal info section
                  _sectionHeader('Personal info'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _firstNameController,
                          hintText: 'First name',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _lastNameController,
                          hintText: 'Last name',
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bioController,
                          hintText: 'Bio (e.g. music style, links)',
                          maxLines: 3,
                          maxLength: 150,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _emailController,
                          hintText: 'Email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Password section
                  _sectionHeader('Change password'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Leave blank to keep current password',
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _surfaceBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildPasswordField(
                          controller: _oldPasswordController,
                          hintText: 'Current password',
                          isVisible: _showOldPassword,
                          onVisibilityToggle: () => setState(() => _showOldPassword = !_showOldPassword),
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: _newPasswordController,
                          hintText: 'New password',
                          isVisible: _showNewPassword,
                          onVisibilityToggle: () => setState(() => _showNewPassword = !_showNewPassword),
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm new password',
                          isVisible: _showConfirmPassword,
                          onVisibilityToggle: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Save changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  /// Generic text field for name, email, bio, etc.
  /// [maxLength] limits input to that many characters (e.g. 150 for bio).
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: maxLength != null
          ? (context, {required currentLength, required isFocused, maxLength}) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '$currentLength / $maxLength',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
          : null,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _textMuted, fontSize: 15, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: darkBackgroundTertiary.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: purpleAccent, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        counterText: '', // hide default counter when using buildCounter
      ),
    );
  }

  /// Password field with visibility toggle
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool isVisible,
    required VoidCallback onVisibilityToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _textMuted, fontSize: 15, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: darkBackgroundTertiary.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: purpleAccent, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: _textMuted,
            size: 22,
          ),
          onPressed: onVisibilityToggle,
        ),
      ),
    );
  }
}
