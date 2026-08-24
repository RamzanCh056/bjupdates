import 'dart:convert';

import 'package:beatjerky/Stripe/stripe_popup.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:http/http.dart' as http;



class SubscriptionServicefull {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? paymentIntent;
  String? tum;
  String collectionPath = 'scan_records';
  String priceId = '';
  int clickCount = 0;
  String? paymentMethodId;
  
 Color _premiumPurple = Color(0xFF9B42F5);
 Color _premiumPurpleLight = Color(0xFFB366FF);
  bool _isLoading = false;
  late BuildContext _context; // Store context for toast

 Future<void> showSubscriptionPopup(BuildContext context, String email) async {
    _context = context; // Store context for toast

    // Reset loading state before showing popup
    _isLoading = false;

    // Fetch the price by product ID
    Map<String, dynamic>? priceDetails = await getPriceByProductId(
      'prod_U0eYVIzZmcoNin',
    );
    if (priceDetails == null) {
      _showToast("No price found for this product.", false);
      return;
    }

    // Extract relevant information
    priceId = priceDetails['id'];
    tum = (priceDetails['unit_amount'] != null)
        ? (priceDetails['unit_amount'] / 100).toString()
        : '0';

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0A0E27), Color(0xFF1A1E3F)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// Title
                      Text(
                        "Subscribe to Enjoy Premium Benefits",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// Premium Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_premiumPurpleLight, _premiumPurple],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// Price
                      Text(
                        "Pay \$$tum per month",
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// Description
                      Text(
                        "Your trial has ended. Subscribe now to continue enjoying premium features.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      /// Buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          /// Proceed Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _premiumPurple,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      // Set loading state
                                      setState(() => _isLoading = true);

                                      try {
                                        String userName = await getUserName(
                                          email,
                                        );

                                        // Close the popup
                                        Navigator.of(context).pop();

                                        // Show card field popup
                                        _showCardFieldPopup(
                                          context,
                                          email,
                                          userName,
                                        );
                                      } catch (e) {
                                        print(
                                          'Error occurred in subscription dialog: $e',
                                        );
                                        // Reset loading state on error
                                        setState(() => _isLoading = false);
                                      }
                                    },
                              child: _isLoading
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                 Color(0xFFFFFFFF)

                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Please Wait",
                                          style: GoogleFonts.nunito(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      "Proceed",
                                      style: GoogleFonts.nunito(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          /// Close Button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton(
                              onPressed: () {
                                // Reset loading state when closing
                                if (_isLoading) {
                                  setState(() => _isLoading = false);
                                }
                                Navigator.of(context).pop();
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.15),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                "Close",
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  String get SECRET_KEY =>
      (dotenv.env['STRIPE_SECRET'] ?? '').trim();

  Future<String> getUserName(String email) async {
    try {
      final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('usersData')
          .where('email', isEqualTo: email)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.get('name');
      } else {
        return 'User';
      }
    } catch (error) {
      print('Error fetching user name: $error');
      return 'User';
    }
  }

  Future<Map<String, dynamic>?> getPriceByProductId(String productId) async {
    try {
      var response = await http.get(
        Uri.parse('https://api.stripe.com/v1/prices?product=$productId'),
        headers: {
          'Authorization': 'Bearer $SECRET_KEY',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        if (data['data'] != null && data['data'].isNotEmpty) {
          return data['data'][0];
        }
      } else {
        print('Failed to fetch price: ${response.body}');
      }
    } catch (e) {
      print('Error fetching price: $e');
    }
    return null;
  }

  /// Fetches the product's default price (e.g. Rs 160 PKR when set as default in Stripe).
  /// Use this for 21-day program so the app uses the price you set as default, not the first one in the list.
  Future<Map<String, dynamic>?> getDefaultPriceByProductId(
    String productId,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.stripe.com/v1/products/$productId'
        '?expand[]=default_price',
      );
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $SECRET_KEY',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );

      if (response.statusCode == 200) {
        final product = jsonDecode(response.body) as Map<String, dynamic>;
        final defaultPrice = product['default_price'];
        if (defaultPrice != null) {
          // When expanded, default_price is the full price object
          if (defaultPrice is Map<String, dynamic>) {
            return defaultPrice;
          }
          // If it's just an id, fetch the price
          if (defaultPrice is String) {
            return await getPriceById(defaultPrice);
          }
        }
      }
      // Fallback: first price in list (previous behavior)
      return await getPriceByProductId(productId);
    } catch (e) {
      print('Error fetching default price: $e');
      return await getPriceByProductId(productId);
    }
  }

  Future<Map<String, dynamic>?> getPriceById(String priceId) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.stripe.com/v1/prices/$priceId'),
        headers: {
          'Authorization': 'Bearer $SECRET_KEY',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching price by id: $e');
    }
    return null;
  }

  void _showCardFieldPopup(BuildContext context, String email, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PaymentPopup(
        email: email,
        priceId: priceId,
        name: name,
        onSuccess: () {
          // Update user subscription status in Firestore
          _updateUserSubscription(email);

          // Show success message
         

          // Close all modals
          Navigator.of(context).pop();
        },
        onToast: (String message, bool isSuccess) {
          // Show toast message from PaymentPopup
          _showToast(message, isSuccess);
        },
      ),
    );
  }

  Future<void> _updateUserSubscription(String email) async {
    try {
      await FirebaseFirestore.instance
          .collection('usersData')
          .where('email', isEqualTo: email)
          .get()
          .then((querySnapshot) {
            if (querySnapshot.docs.isNotEmpty) {
              querySnapshot.docs.first.reference.update({
                'hasSubscription': true,
                'subscriptionActive': true,
                'subscriptionDate': FieldValue.serverTimestamp(),
              });
            }
          });
    } catch (e) {
      print('Error updating subscription: $e');
    }
  }

  /// 21-day program one-time purchase (product id: prod_TrW31WvxSZ7WQg).
  /// Uses the product's default price in Stripe (e.g. Rs 160 PKR when set as default).
  /// On success writes to Firebase collection webpaiduser21dayprogram.
 
  void _showToast(String message, bool isSuccess) {
    Color backgroundColor = isSuccess ? Colors.green : Colors.red;

    // Using ScaffoldMessenger for SnackBar (better UX)
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Also show Fluttertoast as backup
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: backgroundColor,
      timeInSecForIosWeb: 3,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }
}
