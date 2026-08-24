import 'package:beatjerky/notification_services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import '../../eula.dart';
import '../../widget/backward_button.dart';
import '../../widget/reusable_text.dart';
import '../../widget/reusable_textformfield.dart';
import '../../widget/round_button.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Text controllers for all fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  bool eulaAcceptance = false;
  bool pass = true;

  String? deviceId;

  @override
  void initState() {
    super.initState();
    generateAndSaveToken();
  }

  void generateAndSaveToken() async {
    deviceId = await NotificationService.getToken();
    print('FCM Token: $deviceId');
  }

  Future<void> _signUpUser() async {
    if (_formKey.currentState!.validate() && eulaAcceptance) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create user with Firebase Auth
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim(),
            );

        // Save user data to Firestore
        await FirebaseFirestore.instance
            .collection('usersData')
            .doc(userCredential.user!.uid)
            .set({
              'docId': userCredential.user!.uid,
              'firstName': firstNameController.text.trim(),
              'secondName': lastNameController.text.trim(),
              'email': emailController.text.trim(),
              'password': passwordController.text.trim(),
              'createdAt': Timestamp.now(),
              'following': <String>[],
              'subscription': 'unpaid',
              'roles': ['listener'],
            });

        EasyLoading.dismiss();
        AppToast.show('Sign up successful');

        // Navigate to login screen
        Get.to(() => const LoginScreen(selectedRole: ''));
      } on FirebaseAuthException catch (e) {
        EasyLoading.dismiss();
        String errorMessage = e.message ?? 'Sign up failed';
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already registered';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak';
        }
        AppToast.show(errorMessage, isError: true);
      } catch (e) {
        EasyLoading.dismiss();
        AppToast.show('An error occurred', isError: true);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [blackColor, const Color(0xFF0A0A0A), blackColor],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with back button and title
                    Row(
                      children: [
                        const BackwardButton(),
                        const SizedBox(width: 20),
                        const ReusableText(
                          title: "Create Account",
                          size: 24,
                          weight: FontWeight.bold,
                          color: whiteColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Logo section
                    Center(
                      child: Column(
                        children: [
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
                                  color: indigoColor.withOpacity(0.2),
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
                          const ReusableText(
                            title: "Join Us Today!",
                            size: 28,
                            weight: FontWeight.bold,
                            color: whiteColor,
                          ),
                          const SizedBox(height: 8),
                          ReusableText(
                            title: "Create your account to get started",
                            size: 16,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // First Name Field
                    const ReusableText(
                      title: "First Name",
                      size: 14,
                      weight: FontWeight.w600,
                      color: whiteColor,
                    ),
                    const SizedBox(height: 12),
                    ReusableTextForm(
                      controller: firstNameController,
                      capitalize: TextCapitalization.words,
                      hintText: "Enter your first name",
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Last Name Field
                    const ReusableText(
                      title: "Last Name",
                      size: 14,
                      weight: FontWeight.w600,
                      color: whiteColor,
                    ),
                    const SizedBox(height: 12),
                    ReusableTextForm(
                      controller: lastNameController,
                      capitalize: TextCapitalization.words,
                      hintText: "Enter your last name",
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

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
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email';
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
                      obscureText: pass,
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      suffixIcon: InkWell(
                        onTap: () {
                          setState(() {
                            pass = !pass;
                          });
                        },
                        child: Icon(
                          pass
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // EULA Agreement
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lightBlackColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: eulaAcceptance
                              ? indigoColor.withOpacity(0.5)
                              : Colors.grey.shade800,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Transform.scale(
                            scale: 1.1,
                            child: Theme(
                              data: ThemeData(
                                unselectedWidgetColor: Colors.grey.shade600,
                              ),
                              child: Checkbox(
                                value: eulaAcceptance,
                                activeColor: indigoColor,
                                checkColor: whiteColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    eulaAcceptance = value ?? false;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                alignment: WrapAlignment.start,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                runAlignment: WrapAlignment.center,
                                spacing: 0,
                                runSpacing: 0,
                                children: [
                                  ReusableText(
                                    title: "By checking, you agree with our ",
                                    size: 13,
                                    color: Colors.grey.shade300,
                                  ),
                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return Theme(
                                            data: ThemeData.dark(),
                                            child: AlertDialog(
                                              backgroundColor: const Color(
                                                0xFF1E1E1E,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const ReusableText(
                                                title:
                                                    "End User License Agreement",
                                                size: 18,
                                                weight: FontWeight.bold,
                                                color: whiteColor,
                                              ),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    eula,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade300,
                                                      fontSize: 14,
                                                      height: 1.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: ReusableText(
                                                    title: "Close",
                                                    size: 14,
                                                    weight: FontWeight.w600,
                                                    color: indigoColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: pinkColor,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      child: ShaderMask(
                                        shaderCallback: (bounds) =>
                                            buttonGradient.createShader(bounds),
                                        child: const ReusableText(
                                          title: "EULA",
                                          size: 13,
                                          weight: FontWeight.bold,
                                          color: whiteColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sign Up Button
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: eulaAcceptance
                          ? RoundButton(
                              title: _isLoading
                                  ? "Creating Account..."
                                  : "Sign Up",
                              onTap: _isLoading ? () {} : _signUpUser,
                            )
                          : Container(
                              height: 50,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.shade800.withOpacity(0.3),
                              ),
                              child: ReusableText(
                                title: "Accept EULA to continue",
                                size: 16,
                                weight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
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

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ReusableText(
                          title: "Already have an account? ",
                          size: 15,
                          color: Colors.grey.shade400,
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: pinkColor, width: 2),
                              ),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) =>
                                  buttonGradient.createShader(bounds),
                              child: const ReusableText(
                                title: "Log in",
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
    );
  }
}
