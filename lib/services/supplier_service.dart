import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:beatjerky/models/supplier_models.dart';
import 'package:beatjerky/utils/debug_log.dart';

/// App-side data access for the Suppliers & equipment marketplace.
///
///   supplierListings/{id}
///   supplierListings/{id}/requests/{requesterUid}
class SupplierService {
  SupplierService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> get _listings =>
      _db.collection('supplierListings');

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // --- images ---------------------------------------------------------------

  static Future<String?> uploadImage(File file) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = _storage.ref().child(
            'supplier_listings/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e, s) {
      logDebugException('SupplierService.uploadImage', e, stackTrace: s);
      return null;
    }
  }

  // --- browse ---------------------------------------------------------------

  /// Active listings, newest first. Category/city/query filtered client-side.
  static Stream<List<SupplierListing>> watchMarketplace({
    String? category,
    String? city,
    bool activeOnly = true,
  }) {
    final cat = (category ?? '').trim();
    final cityQ = (city ?? '').trim().toLowerCase();
    return _listings
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) {
      var list = snap.docs.map(SupplierListing.fromDoc).toList();
      if (activeOnly) {
        list = list.where((l) => l.status == ListingStatus.active).toList();
      }
      if (cat.isNotEmpty) {
        list = list.where((l) => l.category == cat).toList();
      }
      if (cityQ.isNotEmpty) {
        list = list
            .where((l) => (l.city ?? '').toLowerCase().contains(cityQ))
            .toList();
      }
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('SupplierService.watchMarketplace', e, stackTrace: s);
    });
  }

  static Stream<List<SupplierListing>> watchMyListings(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _listings
        .where('supplierUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(SupplierListing.fromDoc).toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('SupplierService.watchMyListings', e, stackTrace: s);
    });
  }

  static Stream<SupplierListing?> watchOne(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _listings.doc(id).snapshots().map(
          (d) => d.exists ? SupplierListing.fromDoc(d) : null,
        );
  }

  // --- create / update ------------------------------------------------------

  static Future<String?> createListing({
    required String title,
    required String category,
    required String description,
    required String supplierName,
    String? supplierPhoto,
    String? priceInfo,
    String? city,
    String? region,
    List<String> imageUrls = const [],
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final ref = await _listings.add(<String, dynamic>{
        'supplierUid': uid,
        'supplierName': supplierName.trim(),
        'supplierPhoto': supplierPhoto,
        'category': category,
        'title': title.trim(),
        'description': description.trim(),
        'priceInfo': priceInfo?.trim(),
        'city': city?.trim(),
        'region': region?.trim(),
        'imageUrls': imageUrls,
        'status': ListingStatus.active.value,
        'requestCount': 0,
        'createdAt': now,
        'updatedAt': now,
      });
      return ref.id;
    } catch (e, s) {
      logDebugException('SupplierService.createListing', e, stackTrace: s);
      return null;
    }
  }

  static Future<bool> updateListing(
    String id, {
    String? title,
    String? category,
    String? description,
    String? priceInfo,
    String? city,
    String? region,
    List<String>? imageUrls,
  }) async {
    if (id.isEmpty) return false;
    try {
      final data = <String, dynamic>{
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (title != null) data['title'] = title.trim();
      if (category != null) data['category'] = category;
      if (description != null) data['description'] = description.trim();
      if (priceInfo != null) data['priceInfo'] = priceInfo.trim();
      if (city != null) data['city'] = city.trim();
      if (region != null) data['region'] = region.trim();
      if (imageUrls != null) data['imageUrls'] = imageUrls;
      await _listings.doc(id).update(data);
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.updateListing', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> setStatus(String id, ListingStatus status) async {
    if (id.isEmpty) return false;
    try {
      await _listings.doc(id).update(<String, dynamic>{
        'status': status.value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.setStatus', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> deleteListing(String id) async {
    if (id.isEmpty) return false;
    try {
      await _listings.doc(id).delete();
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.deleteListing', e, stackTrace: s);
      return false;
    }
  }

  // --- requests -------------------------------------------------------------

  static CollectionReference<Map<String, dynamic>> _reqs(String id) =>
      _listings.doc(id).collection('requests');

  static Stream<SupplierRequest?> watchMyRequest(String id) {
    final uid = _uid;
    if (uid == null || uid.isEmpty || id.isEmpty) return Stream.value(null);
    return _reqs(id).doc(uid).snapshots().map(
          (d) => d.exists ? SupplierRequest.fromDoc(d) : null,
        );
  }

  static Stream<List<SupplierRequest>> watchRequests(String id) {
    if (id.isEmpty) return Stream.value(const []);
    return _reqs(id).snapshots().map((snap) {
      final list = snap.docs
          .map(SupplierRequest.fromDoc)
          .where((r) => r.status != RequestStatus.withdrawn)
          .toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('SupplierService.watchRequests', e, stackTrace: s);
    });
  }

  /// Current user's requests across all listings.
  /// NOTE: needs a collection-group index on `requesterUid`.
  static Stream<List<SupplierRequest>> watchMyRequests() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return Stream.value(const []);
    return _db
        .collectionGroup('requests')
        .where('requesterUid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(SupplierRequest.fromDoc)
          .where((r) => r.status != RequestStatus.withdrawn)
          .toList();
      list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
      return list;
    }).handleError((Object e, StackTrace s) {
      logDebugException('SupplierService.watchMyRequests', e, stackTrace: s);
    });
  }

  static Future<bool> request({
    required String listingId,
    required String requesterName,
    String? requesterPhoto,
    String message = '',
  }) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || listingId.isEmpty) return false;
    try {
      final reqRef = _reqs(listingId).doc(uid);
      final listingRef = _listings.doc(listingId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(reqRef);
        final firstTime = !snap.exists;
        tx.set(
          reqRef,
          <String, dynamic>{
            'listingId': listingId,
            'requesterUid': uid,
            'requesterName': requesterName.trim(),
            'requesterPhoto': requesterPhoto,
            'message': message.trim(),
            'status': RequestStatus.pending.value,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
        if (firstTime) {
          tx.update(listingRef, <String, dynamic>{
            'requestCount': FieldValue.increment(1),
          });
        }
      });
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.request', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> withdraw(String listingId) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty || listingId.isEmpty) return false;
    try {
      await _reqs(listingId).doc(uid).update(<String, dynamic>{
        'status': RequestStatus.withdrawn.value,
      });
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.withdraw', e, stackTrace: s);
      return false;
    }
  }

  static Future<bool> setRequestStatus(
    String listingId,
    String requesterUid,
    RequestStatus status,
  ) async {
    if (listingId.isEmpty || requesterUid.isEmpty) return false;
    try {
      await _reqs(listingId).doc(requesterUid).update(<String, dynamic>{
        'status': status.value,
      });
      return true;
    } catch (e, s) {
      logDebugException('SupplierService.setRequestStatus', e, stackTrace: s);
      return false;
    }
  }
}
