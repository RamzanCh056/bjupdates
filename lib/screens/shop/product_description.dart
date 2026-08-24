import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../model/api_models/store_models/product_model.dart';
import '../../stripe_payment/stripe_payment.dart';
import '../../utils/color.dart';
import '../../widget/reusable_text.dart';


class ProductDescription extends StatefulWidget {
  const ProductDescription({
    required this.product,
    required this.images,
    required this.storeName,
    Key? key}) : super(key: key);
  final ProductModel product;
  final List<String> images;
  final String storeName;

  @override
  State<ProductDescription> createState() => _ProductDescriptionState();
}

class _ProductDescriptionState extends State<ProductDescription> {
  int itemCount = 1;
  bool isLoading=false;

  @override
  void initState() {
    // initPaymentSheet(context);
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },),
        title: ReusableText(title: widget.product.productName,
          color: Colors.white,
          size: 18,
          weight: FontWeight.w500,),
        actions: [
          Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined, size: 30, color: Colors.white,),
                const SizedBox(width: 67,),
                Positioned(
                    top: -1,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: indigoColor,
                        border: Border.all(color: Colors.white30),
                      ),
                      child: ReusableText(title: itemCount.toString(),
                        color: Colors.white,
                        weight: FontWeight.w400,
                        size: 16,),
                    )),
              ]),
        ],
      ),
      body:
      Padding(
        padding: const EdgeInsets.all(10.0),
        child: SizedBox(
          height: Get.height,
          width: Get.width,
          child: ListView(
            // mainAxisSize: MainAxisSize.min,
            // crossAxisAlignment: CrossAxisAlignment.start,
            shrinkWrap: true,
            children: [
              const SizedBox(height: 10,),
              // SizedBox(
              //     height: 350,
              //
              //     // decoration: BoxDecoration(
              //     //     border: Border.all(color: Colors.white30),
              //     //     borderRadius: BorderRadius.circular(20),
              //     //     image: const DecorationImage(
              //     //       fit: BoxFit.cover,
              //     //       image:  AssetImage("assets/images/product/G8.jpeg"),
              //     //     )
              //     // ),
              //     child: CarouselSlider.builder(
              //       itemCount: widget.images.length,
              //       itemBuilder: (BuildContext context, int itemIndex,
              //           int pageViewIndex) =>
              //           Container(
              //             height: 350,
              //
              //             decoration: BoxDecoration(
              //                 border: Border.all(color: Colors.white30),
              //                 borderRadius: BorderRadius.circular(20),
              //                 image: DecorationImage(
              //                   fit: BoxFit.cover,
              //                   image: NetworkImage(widget.images[itemIndex]
              //                       .replaceAll("public", ApiConstants.baseUrl)),
              //                 )
              //             ),
              //           ),
              //       options: CarouselOptions(
              //         height: 400,
              //         aspectRatio: 16 / 9,
              //         viewportFraction: 0.8,
              //         initialPage: 0,
              //         enableInfiniteScroll: true,
              //         reverse: false,
              //         autoPlay: true,
              //         autoPlayInterval: Duration(seconds: 3),
              //         autoPlayAnimationDuration: Duration(milliseconds: 800),
              //         autoPlayCurve: Curves.fastOutSlowIn,
              //         enlargeCenterPage: true,
              //         enlargeFactor: 0.3,
              //         // onPageChanged: (_,){},
              //         scrollDirection: Axis.horizontal,
              //       ),
              //     )),
              const SizedBox(height: 15,),
              const ReusableText(title: 'Detailed Product',
                color: Colors.white,
                weight: FontWeight.w600,
                size: 18,),
              const SizedBox(height: 10,),
              ReusableText(title: '\$ ${widget.product.productPrice}',
                color: Colors.white,
                weight: FontWeight.w500,
                size: 16,),
              const SizedBox(height: 15,),
              ReusableText(title: widget.product.productDescription,
                color: Colors.white,
                weight: FontWeight.w400,
                size: 16,),
              SizedBox(height: Get.height*.14,),

              // const Spacer(),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 43,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: const Color(0xf30FFFFFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xf40FFFFFF))
                    ),
                    child: Row(

                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.white,),
                          onPressed: itemCount>1?() {
                            setState(() {
                              // itemCount --;
                              itemCount > 1 ? itemCount-- : null;
                            });
                          }:null,),
                        const SizedBox(width: 10,),
                        ReusableText(title: itemCount.toString(),
                          color: Colors.white,
                          size: 20,
                          weight: FontWeight.w400,
                          textAlign: TextAlign.center,),
                        const SizedBox(width: 10,),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.white,),
                          onPressed: () {
                            setState(() {
                              itemCount += 1;
                            });
                          },),
                      ],
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: isLoading?null:() async {
                      setState(() {
                        isLoading=true;
                      });
                      // await makePayment(context);
                      await StripeServices().makePayment(
                        context,
                          widget.product.productPrice.toString()*itemCount,
                        widget.product,
                        widget.storeName
                      );
                      setState(() {
                        isLoading=false;
                      });

                    },
                    child: Container(
                      height: 43,
                      width: Get.width*.4,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: indigoColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xf40FFFFFF))
                      ),
                      child: Center(child: isLoading?SizedBox(height:20,width:20,child: const CircularProgressIndicator()):const ReusableText(
                        title: 'Add to Cart',
                        color: Colors.white,
                        size: 20,
                        weight: FontWeight.w400,
                        textAlign: TextAlign.center,),),
                    ),
                  )

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}