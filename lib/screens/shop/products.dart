// import 'package:beatjerky/screens/shop/product_description.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
// import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
// import 'package:provider/provider.dart';
// import 'package:cached_network_image/cached_network_image.dart';

// import '../../../widget/reusable_text.dart';
// import 'package:animations/animations.dart';

// import '../../consolePrintWithColor.dart';
// import '../../model/api_models/store_models/product_model.dart' show ProductModel;
// import '../../providers/stores_provider/product_provider.dart';
// import '../../repo/api_consts.dart';
// import '../../services/api_services/store_services/get_products.dart';
// import '../../shimmer_effect/music_style_screen_skeleton.dart';
// import '../../utils/color.dart';
// import '../../widget/reusable_textformfield.dart';
// import '../../stripe_payment/stripe_payment.dart';
// import 'package:flutter_easyloading/flutter_easyloading.dart';

// class Products extends StatefulWidget {
//   const Products({required this.storeId, required this.storeName, Key? key})
//       : super(key: key);
//   final int storeId;
//   final String storeName;

//   @override
//   State<Products> createState() => _ProductsState();
// }

// class _ProductsState extends State<Products> {
//   final List<String> items = [
//     'assets/images/shop/baja.jpeg',
//     'assets/images/shop/g1.jpeg',
//     'assets/images/shop/guitar.jpeg',
//     'assets/images/shop/g3.jpeg',
//     'assets/images/shop/g4.jpeg',
//     'assets/images/shop/g2.jpeg',
//     'assets/images/shop/g5.jpeg',
//     'assets/images/shop/g2.jpeg',
//   ];

//   // Track which product is being purchased
//   String? _purchasingProductId;


//   bool isLoading = true;

//   List<ProductModel> searchList=[];
//   searchProduct(String value){
//     searchList.clear();
//     printLog("Search value: ${value}");
//     List<ProductModel> products=Provider.of<ProductProvider>(context,listen: false).productList;
//     for(int i=0; i<products.length;i++){
//       if(products[i].productName.contains(value)){
//         printLog("Value is contained");
//         searchList.add(products[i]);
//       }
//     }
//     setState(() {

//     });
//     // searchList= products.where((element)=>element.productName.contains(value)) as List<ProductModel>;
//   }

//   getProducts() async {
//     await GetProducts.getProducts(context, widget.storeId);
//     setState(() {
//       isLoading = false;
//     });
//   }

//   initializeScreen() async {
//     await getProducts();
//   }

//   @override
//   void initState() {
//     initializeScreen();
//     super.initState();
//   }

//   TextEditingController searchController=TextEditingController();
//   ContainerTransitionType _transitionType = ContainerTransitionType.fadeThrough;

//   // Stripe payment service
//   final StripeServices _stripeServices = StripeServices();

//   // Handle purchase with Stripe
//   Future<void> _handlePurchase(ProductModel product) async {
//     print('Purchase button tapped for product: ${product.productName}');
//     // Show confirmation dialog first
//     bool? confirmPurchase = await showDialog<bool>(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.grey[900],
//           title: const Text(
//             'Confirm Purchase',
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Product: ${product.productName}',
//                 style: const TextStyle(color: Colors.white70),
//               ),
//               const SizedBox(height: 8),
//               Row(
//                 children: [
//                   Text(
//                     'Price: \$${product.productPrice}',
//                     style: const TextStyle(color: Colors.white70),
//                   ),
//                   if (product.productDiscount > 0) ...[
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                       decoration: BoxDecoration(
//                         color: Colors.green,
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Text(
//                         '${product.productDiscount}% OFF',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//                              if (product.productDiscount > 0) ...[
//                  const SizedBox(height: 4),
//                  Text(
//                    'Final Price: \$${(product.productPrice.toDouble() * (1 - product.productDiscount / 100)).toStringAsFixed(2)}',
//                    style: const TextStyle(
//                      color: Colors.green,
//                      fontWeight: FontWeight.bold,
//                    ),
//                  ),
//                ],
//               const SizedBox(height: 8),
//               Text(
//                 'Store: ${widget.storeName}',
//                 style: const TextStyle(color: Colors.white70),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'Are you sure you want to purchase this product?',
//                 style: TextStyle(color: Colors.white),
//               ),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.of(context).pop(false),
//               child: const Text(
//                 'Cancel',
//                 style: TextStyle(color: Colors.grey),
//               ),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(true),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//                 foregroundColor: Colors.white,
//               ),
//               child: const Text('Confirm Purchase'),
//             ),
//           ],
//         );
//       },
//     );

//     if (confirmPurchase != true) return;

//     try {
//       setState(() {
//         _purchasingProductId = product.id.toString();
//       });

//       EasyLoading.show(status: 'Processing payment...');

//       // Calculate final price with discount
//       double finalPrice = product.productPrice.toDouble();
//       if (product.productDiscount > 0) {
//         finalPrice = product.productPrice.toDouble() * (1 - product.productDiscount / 100);
//       }

//       // Convert price to cents (Stripe expects amount in cents)
//       String priceInCents = (finalPrice * 100).round().toString();

//       // Create payment intent
//       var paymentIntent = await _stripeServices.createPaymentIntent(priceInCents);

//       if (paymentIntent['error'] != null) {
//         EasyLoading.dismiss();
//         EasyLoading.showError('Payment failed: ${paymentIntent['error']['message']}');
//         return;
//       }

//       // Display payment sheet
//       await _stripeServices.displayPaymentSheet(
//         context,
//         priceInCents,
//         product,
//         widget.storeName,
//         paymentIntent['id'],
//       );

//       EasyLoading.dismiss();
//     } catch (e) {
//       EasyLoading.dismiss();
//       EasyLoading.showError('Payment error: $e');
//       printLog('Purchase error: $e');
//     } finally {
//       setState(() {
//         _purchasingProductId = null;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(

//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         flexibleSpace: SizedBox(
//           width: Get.width,
//           child: Padding(
//             padding: EdgeInsets.only(top: Get.height*.07),
//             child: const ReusableText(
//               title: 'Product Store',
//               size: 20,
//               weight: FontWeight.w600,
//               color: Color(0xffFFFFFF),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ),
//       ),
//       body: Container(
//           height: MediaQuery
//               .of(context)
//               .size
//               .height,
//           padding: const EdgeInsets.all(10),
//           decoration: const BoxDecoration(
//             color: Color(0xff000000),
//           ),
//           child: ListView(children: [


//             const SizedBox(height: 15),
//             ReusableTextForm(
//               controller: searchController,
//               hintText: "Search Product Name",
//               onChanged: (value){
//                 searchProduct(value);
//                 setState(() {

//                 });
//               },
//               filledColor: Colors.white30,
//               prefixIcon: Icon(
//                 Icons.search,
//                 color: greyColor,
//               ),

//             ),
//             const SizedBox(height: 10),
//             Row(
//               children: const [
//                 Spacer(),
//                 Icon(Icons.list_outlined, color: greyColor,)
//               ],
//             ),

//             const SizedBox(height: 10),
//             !isLoading ? SizedBox(
//               height: MediaQuery
//                   .of(context)
//                   .size
//                   .height * 0.76,
//               child: Provider
//                   .of<ProductProvider>(context, listen: false)
//                   .productList
//                   .isNotEmpty ?
//               GridView.builder(
//                 physics: const ScrollPhysics(),
//                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                    // childAspectRatio: 0.72,
//                    crossAxisSpacing: 10,
//                    mainAxisSpacing: 10,
//                    mainAxisExtent: 320, // Updated to match container height
//                    crossAxisCount: 2, // Two items per row
//                  ),
//                 itemCount: searchList.isNotEmpty || searchController.text.isNotEmpty?searchList.length:Provider
//                     .of<ProductProvider>(context, listen: false)
//                     .productList
//                     .length,
//                 itemBuilder: (BuildContext context, int index) {
//                   return searchList.isEmpty || searchController.text.isEmpty?Consumer<ProductProvider>(

//                     builder: (BuildContext context, product, Widget? _) {
//                                              return Container(
//                            height: 320, // Increased height to accommodate both buttons
//                            decoration: BoxDecoration(
//                              borderRadius: BorderRadius.circular(8),
//                              color: Colors.white30,
//                            ),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Container(
//                                 height: 175,
//                                 child: ClipRRect(
//                                   borderRadius: const BorderRadius.only(
//                                     topLeft: Radius.circular(8),
//                                     topRight: Radius.circular(8),
//                                   ),
//                                   child: CachedNetworkImage(
//                                     imageUrl: product.productList[index].productImg1
//                                         .replaceAll("public", ApiConstants.baseUrl),
//                                     fit: BoxFit.cover,
//                                     width: double.infinity,
//                                     height: double.infinity,
//                                     placeholder: (context, url) => Container(
//                                       color: Colors.grey[800],
//                                       child: const Center(
//                                         child: CircularProgressIndicator(
//                                           strokeWidth: 2,
//                                           valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                         ),
//                                       ),
//                                     ),
//                                     errorWidget: (context, url, error) => Container(
//                                       color: Colors.grey[800],
//                                       child: const Icon(
//                                         Icons.inventory,
//                                         size: 48,
//                                         color: Colors.white24,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ),

//                               // const SizedBox(
//                               //   height: 10,
//                               // ),
//                               Padding(
//                                 padding: const EdgeInsets.symmetric(
//                                     horizontal: 10.0),
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     ReusableText(
//                                       title: product.productList[index]
//                                           .productName,
//                                       size: 14,
//                                       weight: FontWeight.w600,
//                                       color: Color(0xffFFFFFF),
//                                     ),
//                                     const SizedBox(
//                                       height: 10,
//                                     ),
//                                     ReusableText(
//                                       title: '\$ ${product.productList[index]
//                                           .productPrice}',
//                                       size: 13,
//                                       weight: FontWeight.w500,
//                                       color: const Color(0xffFFFFFF),
//                                     ),
//                                     const SizedBox(
//                                       height: 10,
//                                     ),
//                                     // Add to Cart Button
//                                     InkWell(
//                                       onTap: () {
//                                         setState(() {
//                                           Navigator.push(context,
//                                               MaterialPageRoute(
//                                                   builder: (context) {
//                                                     List<String> images = [
//                                                       product.productList[index]
//                                                           .productImg1,
//                                                       product.productList[index]
//                                                           .productImg2,
//                                                       product.productList[index]
//                                                           .productImg3,
//                                                       product.productList[index]
//                                                           .productImg4
//                                                     ];
//                                                     return ProductDescription(
//                                                       product: product
//                                                           .productList[index],
//                                                       images: images,
//                                                       storeName: widget
//                                                           .storeName,);
//                                                   }));
//                                         });
//                                       },
//                                       child: Container(
//                                         width: double.infinity,
//                                         height: 32,
//                                         padding: const EdgeInsets.all(8),
//                                         decoration: BoxDecoration(
//                                             borderRadius: BorderRadius.circular(
//                                                 8),
//                                             color: const Color(0xFFB717DB)),
//                                         child: const Center(
//                                           child: ReusableText(
//                                             title: 'Add to Cart',
//                                             color: Color(0xffFFFFFF),
//                                             size: 12,
//                                             weight: FontWeight.w700,
//                                             textAlign: TextAlign.center,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(height: 8),
//                                     // Purchase Button
//                                     InkWell(
//                                       onTap: _purchasingProductId == product.productList[index].id.toString()
//                                           ? null
//                                           : () => _handlePurchase(product.productList[index]),
//                                       child: Container(
//                                         width: double.infinity,
//                                         height: 32,
//                                         padding: const EdgeInsets.all(8),
//                                         decoration: BoxDecoration(
//                                             borderRadius: BorderRadius.circular(
//                                                 8),
//                                             color: _purchasingProductId == product.productList[index].id.toString()
//                                                 ? Colors.grey
//                                                 : Colors.green),
//                                         child: Center(
//                                           child: _purchasingProductId == product.productList[index].id.toString()
//                                               ? const SizedBox(
//                                                   width: 16,
//                                                   height: 16,
//                                                   child: CircularProgressIndicator(
//                                                     strokeWidth: 2,
//                                                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                                   ),
//                                                 )
//                                               : const Row(
//                                                   mainAxisAlignment: MainAxisAlignment.center,
//                                                   children: [
//                                                     Icon(
//                                                       Icons.payment,
//                                                       color: Colors.white,
//                                                       size: 14,
//                                                     ),
//                                                     SizedBox(width: 4),
//                                                     ReusableText(
//                                                       title: 'Purchase Now',
//                                                       color: Color(0xffFFFFFF),
//                                                       size: 12,
//                                                       weight: FontWeight.w700,
//                                                       textAlign: TextAlign.center,
//                                                     ),
//                                                   ],
//                                                 ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),

//                               ),
//                               const SizedBox(
//                                 height: 10,
//                               ),
//                             ],
//                           ));
//                     },

//                   ):Container(
//                       height: 320, // Increased height to accommodate both buttons
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(8),
//                         color: Colors.white30,
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           ClipRRect(
//                             borderRadius: const BorderRadius.only(
//                                 topRight: Radius.circular(8),
//                                 topLeft: Radius.circular(8)),
//                             child: CachedNetworkImage(
//                                 height: 175,
//                                 width: double.infinity,
//                                 fit: BoxFit.cover,
//                                 imageUrl: searchList[index].productImg1
//                                     .replaceAll("public", ApiConstants.baseUrl),
//                                 placeholder: (context, url) => Container(
//                                   height: 175,
//                                   color: Colors.grey[800],
//                                   child: const Center(
//                                     child: CircularProgressIndicator(
//                                       strokeWidth: 2,
//                                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                     ),
//                                   ),
//                                 ),
//                                 errorWidget: (context, url, error) => Container(
//                                   height: 175,
//                                   color: Colors.grey[800],
//                                   child: const Icon(
//                                     Icons.inventory,
//                                     size: 48,
//                                     color: Colors.white24,
//                                   ),
//                                 ),
//                             ),
//                           ),
//                           // const SizedBox(
//                           //   height: 10,
//                           // ),
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 10.0),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 ReusableText(
//                                   title: searchList[index]
//                                       .productName,
//                                   size: 14,
//                                   weight: FontWeight.w600,
//                                   color: Color(0xffFFFFFF),
//                                 ),
//                                 const SizedBox(
//                                   height: 10,
//                                 ),
//                                 ReusableText(
//                                   title: '\$ ${searchList[index]
//                                       .productPrice}',
//                                   size: 13,
//                                   weight: FontWeight.w500,
//                                   color: const Color(0xffFFFFFF),
//                                 ),
//                                 const SizedBox(
//                                   height: 10,
//                                 ),
//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: InkWell(
//                                         onTap: () {
//                                           setState(() {
//                                             Navigator.push(context,
//                                                 MaterialPageRoute(
//                                                     builder: (context) {
//                                                       List<String> images = [
//                                                         searchList[index]
//                                                             .productImg1,
//                                                         searchList[index]
//                                                             .productImg2,
//                                                         searchList[index]
//                                                             .productImg3,
//                                                         searchList[index]
//                                                             .productImg4
//                                                       ];
//                                                       return ProductDescription(
//                                                         product: searchList[index],
//                                                         images: images,
//                                                         storeName: widget
//                                                             .storeName,);
//                                                     }));
//                                           });
//                                         },
//                                         child: Container(
//                                           height: 28,
//                                           padding: const EdgeInsets.all(5),
//                                           decoration: BoxDecoration(
//                                               borderRadius: BorderRadius.circular(
//                                                   6),
//                                               color: const Color(0xFFB717DB)),
//                                           child: const Center(
//                                             child: ReusableText(
//                                               title: 'Add to Cart',
//                                               color: Color(0xffFFFFFF),
//                                               size: 12,
//                                               weight: FontWeight.w700,
//                                               textAlign: TextAlign.center,
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 8),
//                                                                         Expanded(
//                                       child: InkWell(
//                                         onTap: _purchasingProductId == searchList[index].id.toString()
//                                             ? null
//                                             : () => _handlePurchase(searchList[index]),
//                                         child: Container(
//                                           height: 28,
//                                           padding: const EdgeInsets.all(5),
//                                           decoration: BoxDecoration(
//                                               borderRadius: BorderRadius.circular(
//                                                   6),
//                                               color: _purchasingProductId == searchList[index].id.toString()
//                                                   ? Colors.grey
//                                                   : Colors.green),
//                                           child: Center(
//                                             child: _purchasingProductId == searchList[index].id.toString()
//                                                 ? const SizedBox(
//                                                     width: 16,
//                                                     height: 16,
//                                                     child: CircularProgressIndicator(
//                                                       strokeWidth: 2,
//                                                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                                     ),
//                                                   )
//                                                 : const Row(
//                                                     mainAxisAlignment: MainAxisAlignment.center,
//                                                     children: [
//                                                       Icon(
//                                                         Icons.payment,
//                                                         color: Colors.white,
//                                                         size: 14,
//                                                       ),
//                                                       SizedBox(width: 4),
//                                                       ReusableText(
//                                                         title: 'Purchase',
//                                                         color: Color(0xffFFFFFF),
//                                                         size: 12,
//                                                         weight: FontWeight.w700,
//                                                         textAlign: TextAlign.center,
//                                                       ),
//                                                     ],
//                                                   ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 )
//                               ],
//                             ),

//                           ),
//                           const SizedBox(
//                             height: 10,
//                           ),
//                         ],
//                       ));
//                 },
//               ) :
//               const Center(child: Text("No products available")),
//             ) :
//             const MusicStyleSkeleton(),
//           ])),
//     );
//   }
// }






