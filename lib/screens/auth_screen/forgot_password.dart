import 'package:beatjerky/screens/auth_screen/signup_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../widget/reusable_text.dart';
import '../../widget/reusable_textformfield.dart';
import '../../widget/round_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final _form = GlobalKey<FormState>();

  bool pass = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const ReusableText(
            title: "Forgot Password",
            size: 24,
            weight: FontWeight.bold,
            color: Colors.white,
          ),
          automaticallyImplyLeading: false,
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(15.0),
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row(
                  //   children: const [
                  //     BackwardButton(),
                  //     SizedBox(
                  //       width: 20,
                  //     ),
                  //     ReusableText(
                  //       title: "Log in",
                  //       size: 24,
                  //       weight: FontWeight.bold,
                  //       color: whiteColor,
                  //     ),
                  //   ],
                  // ),
                  Center(
                    child: SizedBox(
                      height: 150,
                      width: 150,
                      child: Image.asset(
                        "assets/images/logo.png",
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),

                  const ReusableText(
                    title: "Email",
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  ReusableTextForm(
                    controller: emailController,
                    hintText: "Email",
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      } else if (!value.contains('@') && !value.contains('.com')) {
                        return 'Invalid email';
                      } else {
                        return null;
                      }
                    },
                    // prefixIcon: Icon(
                    //   Icons.email_outlined,
                    //   color: whiteColor,
                    // ),
                  ),

                  const SizedBox(
                    height: 20,
                  ),
                  RoundButton(
                    title: "Submit",
                    onTap: () async {
                      if (_form.currentState!.validate()) {
                        EasyLoading.show(status: "Loading...");
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: emailController.text.trim());
                          EasyLoading.dismiss();
                          AppToast.show("Password reset email sent. Please check your inbox.");
                          Navigator.pop(context);
                        } catch (e) {
                          EasyLoading.dismiss();
                          AppToast.show("Failed to send password reset email. Please try again.", isError: true);
                        }
                      }
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ReusableText(
                        title: "Don't have an account?",
                        size: 16,
                        color: Colors.white,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (BuildContext context) {
                              return const SignupScreen();
                            }),
                          );
                        },
                        child: const ReusableText(
                          title: "Sign Up",
                          size: 16,
                          color: Colors.white,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
  }
}
