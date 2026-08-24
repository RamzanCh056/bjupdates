import 'dart:developer';

import 'package:beatjerky/notification_services/trigger_notification_services.dart';
import 'package:beatjerky/notification_services/email_service.dart';
import 'package:beatjerky/screens/order_screen/models/order_model.dart';
import 'package:beatjerky/screens/order_screen/services/order_services.dart';
import 'package:beatjerky/screens/store/store_product/product_screen.dart';
import 'package:beatjerky/stripe_payment/stripe_payment.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class ProductCheckoutScreen extends StatefulWidget {
  final String productId;
  final String productImg;
  final String storeId;
  final dynamic productPrice;
  final String productName;

  const ProductCheckoutScreen({
    Key? key,
    required this.productId,
    required this.productImg,
    required this.storeId,
    this.productPrice,
    required this.productName,
  }) : super(key: key);

  @override
  State<ProductCheckoutScreen> createState() => _ProductCheckoutScreenState();
}

class _ProductCheckoutScreenState extends State<ProductCheckoutScreen> {
  final TextEditingController _addressController = TextEditingController();
  final ValueNotifier<int> _quantityNotifier = ValueNotifier<int>(1);

  @override
  void dispose() {
    _addressController.dispose();
    _quantityNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFBB86FC);
    const secondaryColor = Color(0xFFBB86FC);
    final productPrice = widget.productPrice;
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Product Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image Card
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: widget.productImg.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.productImg,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          placeholder: (context, url) => Container(
                            color: const Color(0xFF2A2A2A),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFBB86FC)
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: const Color(0xFF2A2A2A),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              size: 56,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF2A2A2A),
                          child: const Icon(
                            Icons.shopping_bag_rounded,
                            size: 56,
                            color: Colors.white54,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Product Name and Price (directly below image)
            Text(
              widget.productName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${productPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFFBB86FC),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),

            const SizedBox(height: 24),

            // Quantity Selector Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<int>(
                  valueListenable: _quantityNotifier,
                  builder: (context, quantity, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F1F1F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Minus Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: quantity > 1
                                  ? () => _quantityNotifier.value--
                                  : null,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: quantity > 1
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    bottomLeft: Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: quantity > 1
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.3),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Quantity Display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Plus Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _quantityNotifier.value++,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(12),
                                    bottomRight: Radius.circular(12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
 const Text(
                  'Delivery Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
            // Delivery Address Card
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final result = await showDialog<String>(
                    context: context,
                    builder: (context) => _AddressInputDialog(
                      initialAddress: _addressController.text,
                    ),
                  );
                  if (result != null) {
                    _addressController.text = result;
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _addressController.text.isEmpty
                              ? 'Tap to add address'
                              : _addressController.text,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _addressController.text.isEmpty
                                ? Colors.white.withOpacity(0.4)
                                : Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.4),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Total Amount Summary
            ValueListenableBuilder<int>(
              valueListenable: _quantityNotifier,
              builder: (context, quantity, _) {
                final totalPrice = productPrice * quantity;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFBB86FC),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            const SizedBox(height: 8),

            // Pay Now Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFBB86FC),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () async {
                  final address = _addressController.text.trim();
                  if (address.isEmpty) {
                    AppToast.show('Please enter a delivery address', isError: true);
                    return;
                  }

                  final quantity = _quantityNotifier.value;
                  final totalPrice = productPrice * quantity;

                  await _handlePurchase(
                    context: context,
                    totalprice: totalPrice,
                    quantity: quantity,
                  );
                },
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  StripeServices get _stripeServices => StripeServices();

  final _firestore = FirebaseFirestore.instance;

  Future<void> _handlePurchase({
    required BuildContext context,
    required dynamic totalprice,
    required int quantity,
  }) async {
    // Show confirmation dialog first
    bool? confirmPurchase = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        const primaryColor = Color(0xFFBB86FC);
        const secondaryColor = Color(0xFFBB86FC);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF16213E),
                  const Color(0xFF0F1624),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor.withOpacity(0.3), secondaryColor.withOpacity(0.3)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    color: Color(0xFFBB86FC),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Confirm Purchase',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Product:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.productName,
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                '\$',
                                style: TextStyle(
                                  color: Color(0xFF00D4AA),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                totalprice.toStringAsFixed(2),
                                style: const TextStyle(
                                  color: Color(0xFF00D4AA),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Are you sure you want to proceed?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00D4AA), Color(0xFF00A8E8)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: const Center(
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmPurchase != true) return;

    try {
      EasyLoading.show(status: 'Processing payment...');

      // Convert price to cents (Stripe expects amount in cents)
      String priceInCents = (totalprice * 100).round().toString();


      // Create a mock product model for Stripe service
      final mockProduct = MockProductModel(
        id: int.tryParse(widget.productId) ?? 0,
        productName: widget.productName,
        productPrice: totalprice.round(),
        productDiscount: 0,
        storeId: widget.storeId,
      );

      // Create payment intent
      var paymentIntent = await _stripeServices.createPaymentIntent(
        priceInCents,
      );

      // Initialize payment sheet first
      try {
        var gpay = const PaymentSheetGooglePay(
          merchantCountryCode: "US",
          currencyCode: "US",
          testEnv: false,
        );

        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: paymentIntent['client_secret'],
            customerId: null,
            customFlow: true,
            style: ThemeMode.dark,
            merchantDisplayName: "BeatJerky",
            googlePay: gpay,
            allowsDelayedPaymentMethods: true,
          ),
        );

        // Now display the payment sheet and handle the result
        final paymentResult = await _stripeServices.displayPaymentSheet(
          context,
          priceInCents,
          mockProduct,
          widget.storeId, // Store name placeholder
          paymentIntent['id'],
        );

        print("payment result: ${paymentResult}");

        // Only show success if payment was actually completed
        if (paymentResult == true) {
          // Create order in Firebase
          await _createOrder(mockProduct, totalprice);

          EasyLoading.dismiss();
          EasyLoading.showSuccess(
            'Payment completed successfully! Order created.',
          );
          Navigator.pop(context);
        } else {
          EasyLoading.dismiss();
          EasyLoading.showInfo('Payment was cancelled or failed.');
        }
      } catch (stripeError) {
        EasyLoading.dismiss();
        EasyLoading.showError('Stripe initialization error: $stripeError');
        print('Stripe initialization error: $stripeError');
      }
    } catch (e) {
      EasyLoading.dismiss();
      EasyLoading.showError('Payment error: $e');
      print('Purchase error: $e');
    }
  }

  // // Create order after successful payment
  Future<void> _createOrder(MockProductModel product, double price) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final orderService = OrderService();
      if (currentUser == null) return;

      // Get store information
      final storeDoc = await _firestore
          .collection('stores')
          .doc(widget.storeId)
          .get();
      final storeData = storeDoc.data();
      final storeName = storeData?['name'] ?? 'Unknown Store';
      final storeOwnerId = storeData?['userId'] ?? '';
      final quantity = _quantityNotifier.value;
      final userDoc = await _firestore
          .collection("usersData")
          .doc(currentUser.uid)
          .get();
      final buyerData = userDoc.data();
      final sellerDoc = await _firestore
          .collection("usersData")
          .doc(storeOwnerId)
          .get();
      final sellerData = sellerDoc.data();

      final newOrder = OrderModel(
        orderId: '',
        productId: widget.productId,
        productName: widget.productName,
        productImage: widget.productImg,
        quantity: quantity,
        price: price.toInt(),
        buyerId: currentUser.uid,
        buyerName: buyerData?['firstName'] ?? "",
        sellerId: storeOwnerId,
        sellerName: sellerData?['firstName'] ?? "",
        status: 'pending',
        createdAt: Timestamp.now(),
        dispatchedAt: null,
        deliveredAt: null,
        paymentStatus: 'Completed',
        paymentMethod: 'Stripe',
        orderStatus: 'Pending',
        storeId: widget.storeId,
        storeName: storeName,
      );

      await orderService.createOrder(order: newOrder);
      _sendsoldNotification(buyerName: buyerData?['firstName'], buyerid: currentUser.uid, price: price, productName: widget.productName, quentity: quantity, sellersid: storeOwnerId, sellersfcmToken: sellerData?['fcmToken']);
    } catch (e) {
      print('Error creating order: $e');
    }
  }

  Future<void> _sendsoldNotification({
    required String sellersfcmToken,
    required String buyerName,
    required String buyerid,
    required String productName,
    required int quentity,
    required double price,
    required String sellersid,
  }) async {
    try {
      final title = "🎉 You've Made a Sale!";
      final body =
          "$buyerName just purchased $quentity × $productName for \$${price.toStringAsFixed(2)}.";

      if (sellersfcmToken.isNotEmpty) {
        // Send push notification
        final trigger = TriggerNotificationService();
        await trigger.sendPushNotification(
          token: sellersfcmToken,
          title: title,
          body: body,
        );
      }
      // Save notification to Firestore
      final notificationData = {
        'type': 'sold',
        'fromUserId': buyerid,
        'fromUserName': buyerName,
        'timestamp': FieldValue.serverTimestamp(),
        'message': body,
        'isRead': false,
      };
      await _firestore
          .collection('notifications')
          .doc(sellersid)
          .collection('userNotifications')
          .add(notificationData);


      final sellerDoc = await _firestore.collection("usersData").doc(sellersid).get();
      final sellerData = sellerDoc.data();
      final sellerEmail = sellerData?['email'];

      if (sellerEmail != null && sellerEmail.isNotEmpty) {
        final emailService = EmailService();

        final emailBody = '''
          <h2>Congratulations ${sellerData?['firstName']}!</h2>
          <p>You’ve made a new sale 🎉</p>
          <p><b>Buyer:</b> $buyerName</p>
          <p><b>Product:</b> $productName</p>
          <p><b>Quantity:</b> $quentity</p>
          <p><b>Total:</b> \$${price.toStringAsFixed(2)}</p>
          <br>
          <p>Keep up the great work! 💼</p>
          <p><i>— The BeatJerky Team</i></p>
        ''';

        await emailService.sendEmail(
          to: sellerEmail,
          subject: "🎉 New Sale: $productName Sold!",
          body: emailBody,
        );
      }


    } catch (e) {
      log('Error sending notification: $e');
    }
  }
}

// Address Input Dialog
class _AddressInputDialog extends StatefulWidget {
  final String initialAddress;

  const _AddressInputDialog({required this.initialAddress});

  @override
  State<_AddressInputDialog> createState() => _AddressInputDialogState();
}

class _AddressInputDialogState extends State<_AddressInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFBB86FC);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your delivery address',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: primaryColor,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _controller.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Quantity Button Widget
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFBB86FC);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: onTap != null
              ? primaryColor.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null ? primaryColor : Colors.white.withOpacity(0.3),
          size: 20,
        ),
      ),
    );
  }
}
