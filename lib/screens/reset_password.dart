import 'package:beatjerky/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class ResetPassword extends StatefulWidget {
  const ResetPassword({super.key});

  @override
  State<ResetPassword> createState() => _ResetPasswordState();
}

class _ResetPasswordState extends State<ResetPassword> {
  bool _isVisible = true;
  bool _isVisibleOne = true;
  bool _isVisibleTwo = true;
  TextEditingController oldPasswordController = TextEditingController();
  TextEditingController newPasswordController = TextEditingController();
  TextEditingController confirmnewPasswordController = TextEditingController();
  Future<void> resetPassword(String oldPassword, String newPassword) async {

    try {
      // String url = '${ApiConstants.baseUrl}${ApiConstants.resetPassword}';

      Map<String, String> requestBody = {
        // 'userId': provider.user!.userId.toString(),
        'currentPassword': oldPassword,
        'newPassword': newPassword,
      };

      print('Request body: $requestBody');

      http.Response response =
          await http.put(Uri.parse(''), body: requestBody);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('Password reset successfully');
      } else {
        print('Error resetting password. Status code: ${response.statusCode}');
        throw Exception('Password reset failed');
      }
    } catch (e) {
      print('Error resetting password: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff2F2F2F),
      appBar: AppBar(
        backgroundColor: Color(0xff2F2F2F),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Reset password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontFamily: 'Lexend Deca',
            fontWeight: FontWeight.w400,
            height: 0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Old Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: 'Lexend Deca',
                      fontWeight: FontWeight.w400,
                      height: 0,
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: 45,
                    child: TextField(
                      controller: oldPasswordController,
                      obscureText: _isVisible,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Old Password',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1A1),
                          fontSize: 15,
                          fontFamily: 'Lexend Deca',
                          fontWeight: FontWeight.w400,
                          height: 0,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isVisible = !_isVisible;
                            });
                          },
                          child: _isVisible
                              ? Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.visibility_off,
                                  color: Colors.white,
                                ),
                        ),
                        fillColor: Color(0xFF242424),
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    'New Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: 'Lexend Deca',
                      fontWeight: FontWeight.w400,
                      height: 0,
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: 45,
                    child: TextField(
                      controller: newPasswordController,
                      obscureText: _isVisibleOne,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'New Password',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1A1),
                          fontSize: 15,
                          fontFamily: 'Lexend Deca',
                          fontWeight: FontWeight.w400,
                          height: 0,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isVisibleOne = !_isVisibleOne;
                            });
                          },
                          child: _isVisibleOne
                              ? Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.visibility_off,
                                  color: Colors.white,
                                ),
                        ),
                        fillColor: Color(0xFF242424),
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    'Confirm Password',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontFamily: 'Lexend Deca',
                      fontWeight: FontWeight.w400,
                      height: 0,
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  SizedBox(
                    height: 45,
                    child: TextField(
                      controller: confirmnewPasswordController,
                      obscureText: _isVisibleTwo,
                      style: TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        hintStyle: TextStyle(
                          color: Color(0xFFA1A1A1),
                          fontSize: 15,
                          fontFamily: 'Lexend Deca',
                          fontWeight: FontWeight.w400,
                          height: 0,
                        ),
                        suffixIcon: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isVisibleTwo = !_isVisibleTwo;
                            });
                          },
                          child: _isVisibleTwo
                              ? Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.white,
                                )
                              : Icon(
                                  Icons.visibility_off,
                                  color: Colors.white,
                                ),
                        ),
                        fillColor: Color(0xFF242424),
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                try {
                  if (newPasswordController.text !=
                      confirmnewPasswordController.text) {
                    Get.snackbar("Error", "Passwords do not match",
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        margin: EdgeInsets.all(20),
                        borderRadius: 10,
                        duration: Duration(seconds: 3));
                    return;
                  }

                  EasyLoading.show(status: "Updating...");
                  await resetPassword(oldPasswordController.text,
                      confirmnewPasswordController.text);
                  EasyLoading.dismiss();
                  Get.off(() => SettingsScreen());
                } catch (e) {
                  print(e);
                }
              },
              child: Container(
                width: double.infinity,
                height: 49,
                decoration: ShapeDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.00, -1.00),
                    end: Alignment(0, 1),
                    colors: [Color(0xFFB917DC), Color(0xFFDB05C6)],
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  shadows: [
                    BoxShadow(
                      color: Color(0x2B000000),
                      blurRadius: 4,
                      offset: Offset(0, 0),
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    'Save',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Lexend Deca',
                      fontWeight: FontWeight.w700,
                      height: 0,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 10,
            )
          ],
        ),
      ),
    );
  }
}
