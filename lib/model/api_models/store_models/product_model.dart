class ProductModelFields {
  static const String id = "id";
  static const String productName = "productName";
  static const String productDescription = "productDescription";
  static const String productPrice = "productPrice";
  static const String productDiscount = "productDiscount";
  static const String storeId = "storeId";
  static const String productImg1 = "productImg1";
  static const String productImg2 = "productImg2";
  static const String productImg3 = "productImg3";
  static const String productImg4 = "productImg4";
  static const String createdAt = "createdAt";
  static const String updatedAt = "updatedAt";
}

class ProductModel {
  int id;
  String productName;
  String productDescription;
  int productPrice;
  int productDiscount;
  String storeId;
  String productImg1;
  String productImg2;
  String productImg3;
  String productImg4;
  String createdAt;
  String updatedAt;

  ProductModel({
    required this.id,
    required this.productName,
    required this.productDescription,
    required this.productPrice,
    required this.productDiscount,
    required this.storeId,
    required this.productImg1,
    required this.productImg2,
    required this.productImg3,
    required this.productImg4,
    required this.createdAt,
    required this.updatedAt
  });

  factory ProductModel.fromJson(Map<String, dynamic> json)=>
      ProductModel(
          id: json[ProductModelFields.id],
          productName: json[ProductModelFields.productName]??"",
          productDescription: json[ProductModelFields.productDescription]??"",
          productPrice: json[ProductModelFields.productPrice]??0,
          productDiscount: json[ProductModelFields.productDiscount]??0,
          storeId: json[ProductModelFields.storeId]??"",
          productImg1: json[ProductModelFields.productImg1]??"",
          productImg2: json[ProductModelFields.productImg2]??"",
          productImg3: json[ProductModelFields.productImg3]??"",
          productImg4: json[ProductModelFields.productImg4]??"",
          createdAt: json[ProductModelFields.createdAt]??"",
          updatedAt: json[ProductModelFields.updatedAt]??""
      );

}