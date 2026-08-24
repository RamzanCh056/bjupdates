// lib/screens/store/store_product/store_product.dart
import 'dart:io';

import 'package:beatjerky/screens/order_screen/models/order_model.dart';
import 'package:beatjerky/screens/order_screen/services/order_services.dart';
import 'package:beatjerky/screens/store/store_product/product_checkout.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import '../../../model/api_models/store_models/product_model.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:cached_network_image/cached_network_image.dart';

import '../../../stripe_payment/stripe_payment.dart';

class ProductScreen extends StatefulWidget {
  final String storeId;
  const ProductScreen({required this.storeId, Key? key}) : super(key: key);

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  void _openAddProductSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_shopping_cart,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Add New Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFF3A3A3A)),
                  _AddProductForm(
                    firestore: _firestore,
                    storage: _storage,
                    picker: _picker,
                    storeId: widget.storeId,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
  
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Products',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('products')
            .where('storeId', isEqualTo: widget.storeId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Color(0xFFBB86FC).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Color(0xFFBB86FC).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Color(0xFFBB86FC),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Error Loading Products',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4AA)),
                strokeWidth: 3,
              ),
            );
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBB86FC).withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFBB86FC).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Color(0xFFBB86FC)
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'No Products Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add your first product to get started',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data()! as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _ProductCard(
                  name: data['name'] ?? '',
                  imageUrl: data['imageUrl'] ?? '',
                  price: data['price'] ?? 0,
                  productId: docs[i].id,
                  firestore: _firestore,
                  storeId: widget.storeId,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: _firestore.collection('stores').doc(widget.storeId).get(),
        builder: (context, storeSnapshot) {
          if (storeSnapshot.hasData && storeSnapshot.data != null) {
            final currentUserId = FirebaseAuth.instance.currentUser?.uid;
            final storeData =
                storeSnapshot.data!.data() as Map<String, dynamic>?;
            final isStoreOwner =
                storeSnapshot.hasData &&
                storeSnapshot.data != null &&
                storeData != null &&
                storeData['userId'] == currentUserId;

            return isStoreOwner
                ? Container(
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:recntsColor.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: _openAddProductSheet,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
                    ),
                  )
                : const SizedBox.shrink(); // Hide FAB for non-owners
          }
          return const SizedBox.shrink(); // Hide FAB while loading
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name, imageUrl;
  final dynamic price;
  final String productId;
  final FirebaseFirestore firestore;
  final String storeId;
  _ProductCard({
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.productId,
    required this.firestore,
    required this.storeId,
  });

  // Stripe payment service
  StripeServices get _stripeServices => StripeServices();

  // Handle purchase with Stripe
  Future<void> _handlePurchase(BuildContext context) async {
    print('Purchase button tapped for product: $name');

    // Check if user is trying to purchase their own product
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final storeDoc = await firestore.collection('stores').doc(storeId).get();
    final storeData = storeDoc.data();
    final isStoreOwner = storeData?['userId'] == currentUserId;

    if (isStoreOwner) {
      AppToast.show('You cannot purchase your own products!', isError: true);
      return;
    }

    // Show confirmation dialog first
    bool? confirmPurchase = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Confirm Purchase',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: $name',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: \$$price',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to purchase this product?',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm Purchase'),
            ),
          ],
        );
      },
    );

    if (confirmPurchase != true) return;

    try {
      EasyLoading.show(status: 'Processing payment...');

      // Convert price to cents (Stripe expects amount in cents)
      double priceValue = double.tryParse(price) ?? 0.0;
      String priceInCents = (priceValue * 100).round().toString();

      // Create a mock product model for Stripe service
      final mockProduct = MockProductModel(
        id: int.tryParse(productId) ?? 0,
        productName: name,
        productPrice: priceValue.round(),
        productDiscount: 0,
        storeId: storeId,
      );

      // Create payment intent
      var paymentIntent = await _stripeServices.createPaymentIntent(
        priceInCents,
      );

      if (paymentIntent['error'] != null) {
        EasyLoading.dismiss();
        EasyLoading.showError(
          'Payment failed: ${paymentIntent['error']['message']}',
        );
        return;
      }

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
          'Store', // Store name placeholder
          paymentIntent['id'],
        );

        // Only show success if payment was actually completed
        if (paymentResult == true) {
          // Create order in Firebase
          await _createOrder(mockProduct, priceValue);

          EasyLoading.dismiss();
          EasyLoading.showSuccess(
            'Payment completed successfully! Order created.',
          );
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

  // Create order after successful payment
  Future<void> _createOrder(MockProductModel product, double price) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final orderService = OrderService();
      if (currentUser == null) return;

      // Get store information
      final storeDoc = await firestore.collection('stores').doc(storeId).get();
      final storeData = storeDoc.data();
      final storeName = storeData?['name'] ?? 'Unknown Store';
      final storeOwnerId = storeData?['userId'] ?? '';

      // // Create order document
      // await firestore.collection('orders').add({
      //   'userId': currentUser.uid,
      //   'productId': product.id.toString(),
      //   'productName': product.productName,
      //   'productPrice': price,
      //   'storeId': storeId,
      //   'storeName': storeName,
      //   'orderStatus': 'Pending',
      //   'orderDate': FieldValue.serverTimestamp(),
      //   'paymentStatus': 'Completed',
      //   'paymentMethod': 'Stripe',
      // });

      final newOrder = OrderModel(
        orderId: '',
        productId: product.id.toString(),
        productName: product.productName,
        productImage: product.productImg1,
        quantity: 1,
        price: price.toInt(),
        buyerId: currentUser.uid,
        buyerName: currentUser.displayName ?? "",
        sellerId: storeOwnerId,
        sellerName: storeName,
        status: 'pending',
        createdAt: Timestamp.now(),
        dispatchedAt: null,
        deliveredAt: null,
        paymentStatus: 'Completed',
        paymentMethod: 'Stripe',
        orderStatus: 'Pending',
        storeId: storeId,
        storeName: storeName

      );

      await orderService.createOrder(order: newOrder);
   

      print('Order created successfully for product: ${product.productName}');
    } catch (e) {
      print('Error creating order: $e');
    }
  }

  Future<void> _deleteProduct(BuildContext context) async {
    // Security check - verify the store belongs to current user
    try {
      final storeDoc = await firestore.collection('stores').doc(storeId).get();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (!storeDoc.exists || storeDoc.data()?['userId'] != currentUserId) {
        AppToast.show('You don\'t have permission to delete this product', isError: true);
        return;
      }
    } catch (e) {
      AppToast.show('Error verifying permissions: $e', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Product',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete this product? This action cannot be undone.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
                      onPressed: () async {
                        try {
                          // Delete the product image from storage if it exists
                          if (imageUrl.isNotEmpty) {
                            final ref = FirebaseStorage.instance.refFromURL(imageUrl);
                            await ref.delete();
                          }
                          // Delete the product document
                          await firestore.collection('products').doc(productId).delete();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppToast.show('Product deleted successfully');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            AppToast.show('Error deleting product: $e', isError: true);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
  }

  void _editProduct(BuildContext context) async {
    // Security check - verify the store belongs to current user
    try {
      final storeDoc = await firestore.collection('stores').doc(storeId).get();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (!storeDoc.exists || storeDoc.data()?['userId'] != currentUserId) {
        AppToast.show('You don\'t have permission to edit this product', isError: true);
        return;
      }
    } catch (e) {
      AppToast.show('Error verifying permissions: $e', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Edit Product',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFF3A3A3A)),
                  _EditProductForm(
                    firestore: FirebaseFirestore.instance,
                    storage: FirebaseStorage.instance,
                    picker: ImagePicker(),
                    productId: productId,
                    initialName: name,
                    initialPrice: price,
                    initialImageUrl: imageUrl,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: firestore.collection('stores').doc(storeId).get(),
      builder: (context, storeSnapshot) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final storeData = storeSnapshot.data?.data() as Map<String, dynamic>?;
        final isStoreOwner =
            storeSnapshot.hasData &&
            storeSnapshot.data != null &&
            storeData != null &&
            storeData['userId'] == currentUserId;

       
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F1F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isStoreOwner ? null : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProductCheckoutScreen(
                      productId: productId,
                      productImg: imageUrl,
                      storeId: storeId,
                      productPrice: price,
                      productName: name,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product Image (Left Side)
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFF2A2A2A),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF2A2A2A),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF00D4AA),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: const Color(0xFF2A2A2A),
                                  child: const Icon(
                                    Icons.shopping_bag_rounded,
                                    size: 40,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_rounded,
                                size: 40,
                                color: Colors.white54,
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Product Info (Right Side)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Product Name
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          // Price
                          Text(
                            '\$${price.toString()}',
                            style: const TextStyle(
                              color: Color(0xFFBB86FC),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Action Button
                          if (isStoreOwner)
                            Row(
                              children: [
                                _ActionButton(
                                  icon: Icons.edit_rounded,
                                  color: Color(0xFFBB86FC),
                                  onTap: () => _editProduct(context),
                                ),
                                const SizedBox(width: 8),
                                _ActionButton(
                                  icon: Icons.delete_rounded,
                                  color: Colors.red,
                                  onTap: () => _deleteProduct(context),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFBB86FC),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFFBB86FC),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View Details',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
                          // const SizedBox(height: 8),
                          // // Purchase button row - Always show for testing
                          // InkWell(
                          //   onTap: () => _handlePurchase(context),
                          //   child: Container(
                          //     width: double.infinity,
                          //     height:
                          //         50, // Increased height for better visibility
                          //     margin: const EdgeInsets.symmetric(
                          //       horizontal: 4,
                          //     ), // Minimal margin
                          //     padding: const EdgeInsets.symmetric(
                          //       horizontal: 8,
                          //       vertical: 8,
                          //     ), // Minimal padding
                          //     decoration: BoxDecoration(
                          //       borderRadius: BorderRadius.circular(
                          //         12,
                          //       ), // More rounded corners
                          //       color: const Color(0xFFB717DB), // Purple color
                          //       boxShadow: [
                          //         BoxShadow(
                          //           color: const Color(
                          //             0xFFB717DB,
                          //           ).withOpacity(0.3),
                          //           blurRadius: 8,
                          //           offset: const Offset(0, 4),
                          //         ),
                          //       ],
                          //     ),
                          //     child: const Center(
                          //       child: Row(
                          //         mainAxisAlignment: MainAxisAlignment.center,
                          //         mainAxisSize:
                          //             MainAxisSize.min, // Prevent overflow
                          //         children: [
                          //           Icon(
                          //             Icons.payment,
                          //             color: Colors.white,
                          //             size: 18, // Slightly larger icon
                          //           ),
                          //           SizedBox(width: 8), // Better spacing
                          //           Text(
                          //             'Purchase Now', // Normal text
                          //             style: TextStyle(
                          //               color: Colors.white,
                          //               fontSize:
                          //                   14, // Larger, more readable font
                          //               fontWeight: FontWeight
                          //                   .w600, // Medium weight for elegance
                          //               letterSpacing:
                          //                   0.5, // Better letter spacing
                          //             ),
                          //             textAlign: TextAlign.center,
                          //           ),
                          //         ],
                          //       ),
                          //     ),
                          //   ),
                          // ),

      },
    );
  }
}

class _AddProductForm extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker picker;
  final String storeId;

  const _AddProductForm({
    required this.firestore,
    required this.storage,
    required this.picker,
    required this.storeId,
    Key? key,
  }) : super(key: key);

  @override
  State<_AddProductForm> createState() => _AddProductFormState();
}

class _AddProductFormState extends State<_AddProductForm> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  String _price = '';
  XFile? _pickedImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final img = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (img != null) {
      setState(() => _pickedImage = img);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    String imageUrl = '';

    // 1) upload image if any
    if (_pickedImage != null) {
      final ref = widget.storage.ref().child(
        'product_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(_pickedImage!.path));
      imageUrl = await ref.getDownloadURL();
    }

    // 2) write product doc
    await widget.firestore.collection('products').add({
      'storeId': widget.storeId,
      'name': _name,
      'price': double.parse(_price),
      'imageUrl': imageUrl,
      'created_at': Timestamp.now(),
    });

    setState(() => _loading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: keyboardType,
        validator: validator,
        onSaved: (v) {
          if (hint == 'Product Name') {
            _name = v!.trim();
          } else if (hint == 'Price') {
            _price = v!.trim();
          }
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: accent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.2),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _pickedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            color: accent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add Product Image',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to select (optional)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(_pickedImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Product Name Field
          _buildTextField(
            controller: nameController,
            hint: 'Product Name',
            icon: Icons.shopping_bag,
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 16),
          // Price Field
          _buildTextField(
            controller: priceController,
            hint: 'Price',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
            validator: (v) =>
                double.tryParse(v ?? '') == null ? 'Enter valid price' : null,
          ),
          const SizedBox(height: 28),
          // Add Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _submit();
                      }
                    },
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_shopping_cart, color: Colors.white, size: 24),
              label: Text(
                _loading ? 'Adding...' : 'Add Product',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _EditProductForm extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker picker;
  final String productId;
  final String initialName;
  final String initialPrice;
  final String initialImageUrl;

  const _EditProductForm({
    required this.firestore,
    required this.storage,
    required this.picker,
    required this.productId,
    required this.initialName,
    required this.initialPrice,
    required this.initialImageUrl,
    Key? key,
  }) : super(key: key);

  @override
  State<_EditProductForm> createState() => _EditProductFormState();
}

class _EditProductFormState extends State<_EditProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  XFile? _pickedImage;
  String? _imageUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _priceController = TextEditingController(text: widget.initialPrice.toString());
    _imageUrl = widget.initialImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (img != null) {
      setState(() => _pickedImage = img);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final name = _nameController.text.trim();
      final price = _priceController.text.trim();
      String finalImageUrl = _imageUrl ?? '';

      // Upload new image if picked
      if (_pickedImage != null) {
        // Delete old image if exists
        if (_imageUrl?.isNotEmpty ?? false) {
          try {
            final oldRef = widget.storage.refFromURL(_imageUrl!);
            await oldRef.delete();
          } catch (e) {
            print('Error deleting old image: $e');
          }
        }

        // Upload new image
        final ref = widget.storage.ref().child(
          'product_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(File(_pickedImage!.path));
        finalImageUrl = await ref.getDownloadURL();
      }

      // Update product document
      await widget.firestore
          .collection('products')
          .doc(widget.productId)
          .update({
            'name': name,
            'price': double.parse(price),
            'imageUrl': finalImageUrl,
            'updated_at': Timestamp.now(),
          });

      if (mounted) {
        Navigator.of(context).pop();
        AppToast.show('Product updated successfully');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Error updating product: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: accent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.2),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accent.withOpacity(0.5),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _pickedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(_pickedImage!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _imageUrl != null && _imageUrl!.isNotEmpty
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: _imageUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: const Color(0xFF2A2A2A),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFFBB86FC),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        accent.withOpacity(0.3),
                                        const Color(0xFF6200EE).withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2,
                                    size: 48,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_photo_alternate,
                                color: accent,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _imageUrl != null && _imageUrl!.isNotEmpty
                                  ? 'Change Product Image'
                                  : 'Add Product Image',
                              style: TextStyle(
                                color: accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to select (optional)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 24),
          // Product Name Field
          _buildTextField(
            controller: _nameController,
            hint: 'Product Name',
            icon: Icons.shopping_bag,
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null,
          ),
          const SizedBox(height: 16),
          // Price Field
          _buildTextField(
            controller: _priceController,
            hint: 'Price',
            icon: Icons.attach_money,
            keyboardType: TextInputType.number,
            validator: (v) =>
                double.tryParse(v ?? '') == null ? 'Enter valid price' : null,
          ),
          const SizedBox(height: 28),
          // Update Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white, size: 24),
              label: Text(
                _loading ? 'Updating...' : 'Update Product',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// Action Button Widget
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 18,
        ),
      ),
    );
  }
}

// Mock product model for Stripe integration
class MockProductModel extends ProductModel {
  MockProductModel({
    required int id,
    required String productName,
    required int productPrice,
    required int productDiscount,
    required String storeId,
    String productDescription = '',
    String productImg1 = '',
    String productImg2 = '',
    String productImg3 = '',
    String productImg4 = '',
    String createdAt = '',
    String updatedAt = '',
  }) : super(
         id: id,
         productName: productName,
         productDescription: productDescription,
         productPrice: productPrice,
         productDiscount: productDiscount,
         storeId: storeId,
         productImg1: productImg1,
         productImg2: productImg2,
         productImg3: productImg3,
         productImg4: productImg4,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );
}
