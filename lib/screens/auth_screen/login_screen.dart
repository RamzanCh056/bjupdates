import 'dart:async';
import 'dart:developer';
import 'package:beatjerky/notification_services/notification_services.dart';
import 'package:beatjerky/screens/auth_screen/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../model/api_models/user_model/user_model.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../widget/reusable_text.dart';
import '../../widget/reusable_textformfield.dart';
import '../../widget/round_button.dart';
import '../bottom_nav_bar.dart';
import 'forgot_password.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key, required String selectedRole}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false, _obscure = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _logIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final fcmtoken = await NotificationService.getToken();
      log("device fcm token is : $fcmtoken");

      final user = cred.user!;

      log("user is : ${user.uid}");

      // Update FCM token in Firestore usersData collection
      try {
        await FirebaseFirestore.instance
            .collection('usersData')
            .doc(user.uid)
            .set({
          'fcmToken': fcmtoken,
        }, SetOptions(
          merge: true
        ));
        log("FCM token updated successfully for user: ${user.uid}");
      } catch (e) {
        log("Error updating FCM token: $e");
        // Continue with login even if FCM token update fails
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(UserModelFields.email, user.email!);
      await prefs.setString(UserModelFields.userId, user.uid);
      if (fcmtoken != null) {
        await prefs.setString(UserModelFields.deviceId, fcmtoken!);
      }

      EasyLoading.dismiss();
      Get.offAll(() => const BottomNavBar());
      AppToast.show('Login successful');
    } on FirebaseAuthException catch (e) {
      EasyLoading.dismiss();
      String msg = 'Login failed. Please try again.';
      if (e.code == 'user-not-found') msg = 'No user found for that email.';
      if (e.code == 'wrong-password') msg = 'Wrong password provided.';
      AppToast.show(msg, isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: blackColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: whiteColor),
          titleTextStyle: TextStyle(color: whiteColor, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
        ),
      ),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                blackColor,
                const Color(0xFF0A0A0A),
                blackColor,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Welcome Section
                      Center(
                        child: Column(
                          children: [
                            // Logo with glow effect
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    indigoColor.withOpacity(0.3),
                                    pinkColor.withOpacity(0.2),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: indigoColor.withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: pinkColor.withOpacity(0.2),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    "assets/images/logo.png",
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            // Welcome Text
                            const ReusableText(
                              title: "Welcome Back!",
                              size: 28,
                              weight: FontWeight.bold,
                              color: whiteColor,
                            ),
                            const SizedBox(height: 8),
                            ReusableText(
                              title: "Sign in to continue your journey",
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 48),

                      // Email Field
                      const ReusableText(
                        title: "Email Address",
                        size: 14,
                        weight: FontWeight.w600,
                        color: whiteColor,
                      ),
                      const SizedBox(height: 12),
                      ReusableTextForm(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        hintText: "Enter your email",
                        prefixIcon: Icon(
                          Icons.email_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'This field is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Invalid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Password Field
                      const ReusableText(
                        title: "Password",
                        size: 14,
                        weight: FontWeight.w600,
                        color: whiteColor,
                      ),
                      const SizedBox(height: 12),
                      ReusableTextForm(
                        controller: passwordController,
                        hintText: "Enter your password",
                        obscureText: _obscure,
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        suffixIcon: InkWell(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Forgot Password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: ReusableText(
                            title: "Forgot Password?",
                            size: 14,
                            weight: FontWeight.w600,
                            color: indigoColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: RoundButton(
                          title: _isLoading ? "Signing in..." : "Log in",
                          onTap: _isLoading ? () {} : _logIn,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Divider
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade800,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ReusableText(
                              title: "OR",
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.shade800,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ReusableText(
                            title: "Don't have an account? ",
                            size: 15,
                            color: Colors.grey.shade400,
                          ),
                          InkWell(
                            onTap: () => Get.to(() => const SignupScreen()),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: pinkColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: ShaderMask(
                                shaderCallback: (bounds) => buttonGradient.createShader(bounds),
                                child: const ReusableText(
                                  title: "Sign Up",
                                  size: 15,
                                  weight: FontWeight.bold,
                                  color: whiteColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
