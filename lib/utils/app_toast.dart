import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Shows a toast message using Fluttertoast (replaces SnackBar across the app).
class AppToast {
  static void show(String msg,{bool isError = false}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: isError ? Colors.red : Colors.black87,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
