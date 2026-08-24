import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'dart:developer';
import 'package:flutter/foundation.dart';

import '../consolePrintWithColor.dart';
import '../model/api_models/store_models/product_model.dart';

class StripeServices {
  Map<String, dynamic>? paymentIntent;

  createPaymentIntent(String price) async {
    try {
      Map<String, dynamic> body = {
        "amount": price,
        "currency": "usd",
      //   "automatic_payment_methods[enabled]":"true",
      // "automatic_payment_methods[allow_redirects]":"never",
      //   "confirm":"true",
        "payment_method_types[]":"card"
      };


      http.Response response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        body: body,
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET']}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
      );
      log('create Payment Intent response ----> ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  confirmPaymentIntent(String paymentIntentId) async {
    try {
      Map<String, dynamic> body = {
        "payment_method": "pm_card_visa"
      };

      http.Response response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents/$paymentIntentId/confirm'),
        body: body,
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET']}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
      );
      log('confirm Payment Intent response ----> ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  displayPaymentSheet(
      BuildContext context,
      String price,
      ProductModel product,
      String storeName,
      String paymentIntentId
      ) async {
    try {
      await Stripe.instance.presentPaymentSheet().then((
          value) async {
        var result = await confirmPaymentIntent(paymentIntentId);
        // Stripe.instance.confirmPayment(paymentIntentClientSecret: clientSecret!);
        if(result["status"]=="succeeded"){
          EasyLoading.showSuccess("Transaction Completed Successfully",duration: Duration(seconds: 2));
        }
      }).onError((error, stackTrace) {
        StripeException exception=error as StripeException;
        printLog("error is ${error.toString()}");
        EasyLoading.showError("Failed due to: ${exception.error.message}");
        // Get.showSnackbar(GetSnackBar(message: "Failed due to: $error",
        //   duration: const Duration(seconds: 3),));
      });

      log('Done');
      return true;
    } catch (e) {
      log('failed');
      throw Exception(e.toString());
    }
    
  }

  Future<void> makePayment(
      BuildContext context,
      String price,
      ProductModel product,
      String storeName,) async {
    try {
      if (kIsWeb) {
        log('Stripe for web ----->');
        /*const params = PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
                email: 'atif@gmail.com',
                address: Address(
                    city: 'Peshawar',
                    country: 'Pakistan',
                    line1: 'Metasense',
                    line2: 'Metasense',
                    postalCode: '25000',
                    state: 'KPK'),
                phone: '+923123346785',
                name: 'Muhammad Atif'),
            shippingDetails: ShippingDetails(
              address: Address(
                  city: 'Peshawar',
                  country: 'Pakistan',
                  line1: 'Metasense',
                  line2: 'Metasense',
                  postalCode: '25000',
                  state: 'KPK'),
            ),
          ),
        );

        await Stripe.instance.createPaymentMethod(
          params: params,
        );*/
/*
        Stripe.instance
            .confirmPayment(paymentIntentClientSecret: '', data: params);*/
      } else {
        log('Stripe for android ----->');
        paymentIntent = await createPaymentIntent(price);
        var gpay = const PaymentSheetGooglePay(
          merchantCountryCode: "US",
          currencyCode: "US",
          testEnv: false,
        );

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntent!['client_secret'],
            customerId: null,
            customFlow: true,
            style: ThemeMode.light,
            merchantDisplayName: "BeatJerky",
            googlePay: gpay,
            allowsDelayedPaymentMethods: true,
          ),
        );

        await displayPaymentSheet(context,price, product, storeName,paymentIntent!["id"]);
      }
    } catch (e) {
      log('Payment Error -----> ${e.toString()}');
    }
  }
}




//
// Future<void> makePayment(BuildContext context) async {
//   try {
//     //STEP 1: Create Payment Intent
//     var paymentIntent = await createPaymentIntent('100', 'USD');
//
//     //STEP 2: Initialize Payment Sheet
//     await Stripe.instance
//         .initPaymentSheet(
//
//         paymentSheetParameters: SetupPaymentSheetParameters(
//             paymentIntentClientSecret: paymentIntent![
//             'client_secret'], //Gotten from payment intent
//             style: ThemeMode.light,
//             merchantDisplayName: 'Ikay'))
//         .then((value) {});
//
//     //STEP 3: Display Payment sheet
//     displayPaymentSheet(context);
//   } catch (err) {
//     throw Exception(err);
//   }
// }
//
//
// createPaymentIntent(String amount, String currency) async {
//   try {
//     //Request body
//     Map<String, dynamic> body = {
//       'amount': amount*100,
//       'currency': currency,
//     };
//
//     //Make post request to Stripe
//     var response = await http.post(
//       Uri.parse('https://api.stripe.com/v1/payment_intents'),
//       headers: {
//         'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET']}',
//         'Content-Type': 'application/x-www-form-urlencoded'
//       },
//       body: body,
//     );
//     return json.decode(response.body);
//   } catch (err) {
//     throw Exception(err.toString());
//   }
// }
//
//
//
//
// displayPaymentSheet(BuildContext context) async {
//   try {
//     await Stripe.instance.presentPaymentSheet().then((value) {
//       showDialog(
//           context: context,
//           builder: (_) => AlertDialog(
//             content: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: const [
//                 Icon(
//                   Icons.check_circle,
//                   color: Colors.green,
//                   size: 100.0,
//                 ),
//                 SizedBox(height: 10.0),
//                 Text("Payment Successful!"),
//               ],
//             ),
//           ));
//
//       var paymentIntent = null;
//     }).onError((error, stackTrace) {
//       throw Exception(error);
//     });
//   } on StripeException catch (e) {
//     print('Error is:---> $e');
//     AlertDialog(
//       content: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             children: const [
//               Icon(
//                 Icons.cancel,
//                 color: Colors.red,
//               ),
//               Text("Payment Failed"),
//             ],
//           ),
//         ],
//       ),
//     );
//   } catch (e) {
//     print('$e');
//   }
// }
//
//
// Future<void> initPaymentSheet(BuildContext context) async {
//   try {
//     await stripe.Stripe.instance.initPaymentSheet(
//       paymentSheetParameters: const stripe.SetupPaymentSheetParameters(
//         customFlow: true,
//         merchantDisplayName: 'Flutter Stripe Demo',
//         paymentIntentClientSecret: "",
//         customerEphemeralKeySecret: "",
//         customerId: "",
//         setupIntentClientSecret: "",
//         style: ThemeMode.light,
//       ),
//     );
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Error: $e')),
//     );
//     rethrow;
//   }
// }
//
// // Future<void> displayPaymentSheet(BuildContext context) async {
// //   try {
// //     await stripe.Stripe.instance.presentPaymentSheet(
// //         options: const stripe.PaymentSheetPresentOptions(timeout: 1200000));
// //
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       const SnackBar(
// //         content: Text('Payment successfully completed'),
// //       ),
// //     );
// //   } catch (e) {
// //
// //     ScaffoldMessenger.of(context).showSnackBar(
// //       SnackBar(
// //         content: Text('$e'),
// //       ),
// //     );
// //   }
// // }
