import 'package:beatjerky/screens/order_screen/models/order_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderService {
  final CollectionReference ordersRef = FirebaseFirestore.instance.collection(
    'orders',
  );

  // Place a new order
  Future<String> createOrder({required OrderModel order}) async {
    final docRef = await ordersRef.add(order.toMap());
    return docRef.id;
  }

    /// ✅ Check if 'orders' collection has any data
  Future<bool> isOrdersCollectionEmpty() async {
    final snapshot = await ordersRef.limit(1).get();
    return snapshot.docs.isEmpty;
  }

  /// ✅ Stream purchases for a buyer, but first check collection exists
  Stream<List<OrderModel>> purchasesStream(String buyerId) async* {
    // If no one has any order yet
    if (await isOrdersCollectionEmpty()) {
      yield []; // return empty list
      return;
    }

    yield* ordersRef
        .where('buyerId', isEqualTo: buyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? []
            : snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
  }

  /// ✅ Stream sales for a seller, but first check collection exists
  Stream<List<OrderModel>> salesStream(String sellerId) async* {
    if (await isOrdersCollectionEmpty()) {
      yield [];
      return;
    }

    yield* ordersRef
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.isEmpty
            ? []
            : snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
  }

  Future<void> markAsDispatched(String orderId) async {
    await ordersRef.doc(orderId).update({
      'status': 'dispatched',
      'dispatchedAt': Timestamp.now(),
    });
  }

  Future<void> markAsDelivered(String orderId) async {
    await ordersRef.doc(orderId).update({
      'status': 'delivered',
      'deliveredAt': Timestamp.now(),
    });
  }
}
