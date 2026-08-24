
// import 'package:beatjerky/screens/shop/products.dart';
// import 'package:flutter/material.dart';
// import 'package:animations/animations.dart';
// import 'package:get/get.dart';
// import 'package:get/get_core/src/get_main.dart';
// import 'package:provider/provider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import '../../../widget/reusable_text.dart';
// import '../../providers/stores_provider/store_provider.dart';
// import '../../repo/api_consts.dart';
// import '../../services/api_services/store_services/get_stores.dart';
// import '../../shimmer_effect/music_style_screen_skeleton.dart';
// import '../../utils/color.dart';
// import '../../widget/reusable_textformfield.dart';

// class StoresScreen extends StatefulWidget {
//   const StoresScreen({Key? key}) : super(key: key);

//   @override
//   State<StoresScreen> createState() => _StoresScreenState();
// }

// class _StoresScreenState extends State<StoresScreen> {
//   final List<String> items = [
//     'assets/images/product/makeup.png',
//     'assets/images/product/makeup1.png',
//     'assets/images/product/toy1_1.png',
//     'assets/images/product/toy2_1.png',
//     'assets/images/product/dog.png',
//     'assets/images/product/dumble.png',
//     'assets/images/product/laptop.png',
//     'assets/images/product/game.png',
//     'assets/images/product/pc.png',
//     'assets/images/product/key.png',
//   ];

//   initializeScreen() async {
//     await GetStores.getAllStores(context);
//     setState(() {
//       isLoading = false;
//     });
//   }

//   int productIndex = -1;
//   bool isLoading = true;
  
//   @override
//   void initState() {
//     initializeScreen();
//     super.initState();
//   }

//   int index = -1;
//   ContainerTransitionType _transitionType = ContainerTransitionType.fadeThrough;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: true,
//         elevation: 0,
//         backgroundColor: Colors.black,
//         title: const ReusableText(
//           title: 'Beat Jerky Store',
//           size: 20,
//           weight: FontWeight.w500,
//           color: Color(0xffFFFFFF),
//           textAlign: TextAlign.center,
//         ),
//       ),
//       body: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: const BoxDecoration(
//           color: Color(0xff000000),
//         ),
//         child: !isLoading
//             ? GridView.builder(
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   mainAxisExtent: 235, // Increased to match new card height
//                   crossAxisSpacing: 12, // Increased spacing
//                   mainAxisSpacing: 12, // Increased spacing
//                   crossAxisCount: 2,
//                 ),
//                 itemCount: Provider.of<StoreProvider>(context, listen: false)
//                     .storeList
//                     .length,
//                 itemBuilder: (BuildContext context, int index) {
//                   return Consumer<StoreProvider>(
//                     builder: (context, store, _) => Material(
//                       color: Colors.transparent,
//                       child: InkWell(
//                         borderRadius: BorderRadius.circular(16),
//                         onTap: () {
//                           Get.to(() => Products(
//                                 storeId: store.storeList[index].id,
//                                 storeName: store.storeList[index].storeName,
//                               ));
//                         },
//                         child: AnimatedContainer(
//                           duration: const Duration(milliseconds: 300),
//                           curve: Curves.easeInOut,
//                           height: 220, // Increased height for better proportions
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(16), // More rounded corners
//                             gradient: LinearGradient(
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                               colors: [
//                                 Colors.grey[900]!,
//                                 Colors.grey[850]!,
//                               ],
//                             ),
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.3),
//                                 blurRadius: 10,
//                                 offset: const Offset(0, 5),
//                               ),
//                             ],
//                           ),
//                           child: Stack(
//                             children: [
//                               Column(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 children: [
//                                   Container(
//                                     height: 180, // Adjusted height
//                                     width: double.infinity,
//                                     child: ClipRRect(
//                                       borderRadius: const BorderRadius.only(
//                                         topLeft: Radius.circular(16),
//                                         topRight: Radius.circular(16),
//                                       ),
//                                       child: CachedNetworkImage(
//                                         imageUrl: store
//                                             .storeList[index].storeImage
//                                             .replaceAll("public",
//                                                 ApiConstants.baseUrl),
//                                         fit: BoxFit.cover,
//                                         width: double.infinity,
//                                         height: double.infinity,
//                                         placeholder: (context, url) => Container(
//                                           color: Colors.grey[800],
//                                           child: const Center(
//                                             child: CircularProgressIndicator(
//                                               strokeWidth: 2,
//                                               valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
//                                             ),
//                                           ),
//                                         ),
//                                         errorWidget: (context, url, error) => Container(
//                                           color: Colors.grey[800],
//                                           child: const Icon(
//                                             Icons.store,
//                                             size: 48,
//                                             color: Colors.white24,
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ),

//                                   // Store name with better styling
//                                   Container(
//                                     width: double.infinity,
//                                     padding: const EdgeInsets.symmetric(
//                                         horizontal: 16.0, vertical: 12),
//                                     child: Center(
//                                       child: Text(
//                                         store.storeList[index].storeName,
//                                         style: const TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 16,
//                                           fontWeight: FontWeight.w600,
//                                           letterSpacing: 0.5,
//                                         ),
//                                         textAlign: TextAlign.center,
//                                         overflow: TextOverflow.ellipsis,
//                                         maxLines: 1,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               // Enhanced discount tag
//                               Positioned(
//                                 right: 12,
//                                 top: 12,
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                                   decoration: BoxDecoration(
//                                     borderRadius: BorderRadius.circular(12),
//                                     color: Colors.green,
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: Colors.green.withOpacity(0.3),
//                                         blurRadius: 6,
//                                         offset: const Offset(0, 2),
//                                       ),
//                                     ],
//                                   ),
//                                   child: const Text(
//                                     '10% off',
//                                     style: TextStyle(
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.w700,
//                                       fontSize: 12,
//                                       letterSpacing: 0.5,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               )
//             : const MusicStyleSkeleton(),
//       ),
//     );
//   }
// }
