import 'package:flutter/material.dart';

// Basic Colors
const whiteColor = Color(0xFFFFFFFF);
const blackColor = Color(0xFF000000);
const lightBlackColor = Color(0xFF171717);
const greyColor = Colors.grey;
const transparentColor = Colors.transparent;

// Theme Colors
const indigoColor = Color(0xFFB717DB);
const recntsColor = Color(0xFFBB86FC);
const pinkColor = Color(0xFFD127AE);
Color artistSlowColor = Color(0xFFB717DB).withOpacity(0.4);

// Dark Theme Background Colors (Consistent across app)
const darkBackgroundPrimary = Color(0xFF0A0E27); // Main screen background
const darkBackgroundSecondary = Color(0xFF16213E); // Card/Container background
const darkBackgroundTertiary = Color(0xFF1A2847); // Alternative card background
const darkAppBarBackground = Color(0xFF0A0E27); // AppBar background
const darkCardBackground = Color(0xFF1A2847); // Card backgrounds

// Legacy background (keeping for compatibility)
const backgroundColor = Color(0xFF1D1F3E);

// Accent Colors
const purpleAccent = Color(0xFFBB86FC); // Primary accent (purple)
const cyanAccent = Color(0xFF03DAC6); // Secondary accent (cyan)

// Feature Colors
const eventsColor = Color(0xFF168cff);
const peopleColor = Color(0xFFf9983b);
const storeColor = Color(0xFFf67199);
const redColor = Colors.red;
const greenColor = Colors.green;

// Gradient
Gradient buttonGradient = const LinearGradient(colors: [
  indigoColor,
  pinkColor,
],);

// App Theme Gradient
const appGradient = LinearGradient(
  colors: [recntsColor, indigoColor],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);