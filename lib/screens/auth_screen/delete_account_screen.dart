import 'package:beatjerky/notification_services/notification_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:provider/provider.dart';
import '../../utils/color.dart';
import '../../widget/reusable_text.dart';
import '../../widget/reusable_textformfield.dart' show ReusableTextForm;
import '../../widget/round_button.dart' show RoundButton;
import 'forgot_password.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({Key? key}) : super(key: key);

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  final _form = GlobalKey<FormState>();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const ReusableText(
            title: "Delete Account",
            size: 24,
            weight: FontWeight.bold,
            color: whiteColor,
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
                    color: whiteColor,
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  ReusableTextForm(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    hintText: "Email",
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      } else if (!value.contains('@') &&
                          !value.contains('.com')) {
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
                  const ReusableText(
                    title: "Password",
                    size: 16,
                    color: whiteColor,
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  ReusableTextForm(
                    hintText: "Password",
                    obscureText: pass,
                    suffixIcon: InkWell(
                      onTap: () {
                        setState(() {
                          pass = !pass;
                        });
                      },
                      child: Icon(
                        pass ? Icons.visibility : Icons.visibility_off,
                        color: whiteColor,
                      ),
                    ),
                    controller: passwordController,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      } else {
                        return null;
                      }
                    },
                  ),

                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(onPressed: ()=>Get.to(()=>const ForgotPasswordScreen()),
                  //       child: const Text("Forgot Password?")),
                  // ),

                  const SizedBox(
                    height: 20,
                  ),
                  RoundButton(
                    title: "Delete Account",
                    onTap: () async {
                      // if (_form.currentState!.validate()) {
                      //   emailController.text.replaceAll(" ", "");
                      //   EasyLoading.show(status: "Signing in...");
                      //   bool value = await AuthServices().login(
                      //       emailController.text,
                      //       passwordController.text,
                      //       context,
                      //       deviceId);
                      //   EasyLoading.dismiss();
                      //   if (value) {
                      //     showDialog(
                      //         context: context,
                      //         builder: (context) {
                      //           return AlertDialog(
                      //             content: Text(
                      //                 "Are you sure to delete account, this cannot be reversed"),
                      //             actions: [
                      //               TextButton(
                      //                   onPressed: () async {
                      //                     bool value = await AuthServices()
                      //                         .deleteAccount(
                      //                             Provider.of<CurrentUserProvider>(
                      //                                     context,
                      //                                     listen: false)
                      //                                 .user!
                      //                                 .userId
                      //                                 .toString(),
                      //                             context);
                      //                   },
                      //                   child: Text(
                      //                     "Delete",
                      //                     style: TextStyle(color: Colors.red),
                      //                   )),
                      //               TextButton(
                      //                   onPressed: () {}, child: Text("Cancel"))
                      //             ],
                      //           );
                      //         });
                      //     // await AuthPreferences().setAuthPreferences(emailController.text, passwordController.text);
                      //     // Get.to(()=>const BottomNavBar());
                      //   } else {
                      //     Get.showSnackbar(const GetSnackBar(
                      //       message: "Invalid email or password",
                      //       duration: Duration(seconds: 2),
                      //     ));
                      //   }
                      // }
                    },
                  ),
                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.center,
                  //   children: [
                  //     const ReusableText(
                  //       title: "Don't have an account?",
                  //       size: 16,
                  //       color: whiteColor,
                  //     ),
                  //     TextButton(onPressed: (){
                  //       Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
                  //         return const SignupScreen();
                  //       }),);
                  //     }, child:
                  //     const ReusableText(
                  //       title: "Sign Up",
                  //       size: 16,
                  //       color: whiteColor,
                  //       weight: FontWeight.bold,
                  //     ),),
                  //   ],
                  // )
                ],
              ),
            ),
          ),
        ),
      );
  }
}
