import 'package:cloud_firestore/cloud_firestore.dart';

// Order model
class OrderModel {
  final String orderId;
  final String productId;
  final String productName;
  final String productImage;
  final String storeId;
  final String storeName;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final int quantity;
  final int price; // store price in cents/paise
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final String status; // pending, dispatched, delivered
  final Timestamp createdAt;
  final Timestamp? dispatchedAt;
  final Timestamp? deliveredAt;

  OrderModel({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.quantity,
    required this.price,
    required this.storeId,
    required this.storeName,
    required this.orderStatus,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    required this.status,
    required this.createdAt,
    this.dispatchedAt,
    this.deliveredAt,
  });

  factory OrderModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      orderId: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImage: data['productImage'] ?? '',
      quantity: (data['quantity'] ?? 1) as int,
      price: (data['price'] ?? 0) as int,
      buyerId: data['buyerId'] ?? '',
      buyerName: data['buyerName'] ?? '',
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      dispatchedAt: data['dispatchedAt'],
      deliveredAt: data['deliveredAt'],
      storeId: data['storeId'],
      storeName: data['storeName'],
      orderStatus: data['orderStatus'],
      paymentMethod: data['paymentMethod'],
      paymentStatus: data['paymentStatus']

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'price': price,
      'buyerId': buyerId,
      'buyerName': buyerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'status': status,
      'createdAt': createdAt,
      'dispatchedAt': dispatchedAt,
      'deliveredAt': deliveredAt,
      'storeId': storeId,
      'storeName': storeName,
      'orderStatus': orderStatus,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
    };
  }
}
