import 'package:flutter/cupertino.dart';

double height(context) {
  return MediaQuery.of(context).size.height;
}

double width(context) {
  return MediaQuery.of(context).size.width;
}


responsiveHeight(double value,BuildContext context) {
  double iniH = MediaQuery.of(context).size.height;
  if (iniH < 750) {
    iniH = 844;
  } else {
    iniH = 768;
  }

  return MediaQuery.of(context).size.height * (value / iniH);
}

responsiveWidth(double value,BuildContext context) {
  double iniW = MediaQuery.of(context).size.width;
  if (iniW < 750) {
    iniW = 390;
  } else {
    iniW = 1366;
  }
  return MediaQuery.of(context).size.width * (value / iniW);
}