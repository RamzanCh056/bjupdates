import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart' show readMillis;

/// Suppliers & equipment marketplace.
///
/// A supplier (supplier role) lists a service in `supplierListings/{id}`.
/// Organizers request it through `supplierListings/{id}/requests/{requesterUid}`.

/// Canonical service categories.
const List<String> supplierCategories = [
  'Furniture',
  'Catering & bar',
  'Lighting',
  'Stage & sound',
  'Decor',
  'Security',
  'Transport & logistics',
  'Photo / video',
  'Tents & structures',
];

enum ListingStatus { active, paused }

extension ListingStatusX on ListingStatus {
  String get value => this == ListingStatus.paused ? 'paused' : 'active';
  String get label => this == ListingStatus.paused ? 'Paused' : 'Active';
  bool get isActive => this == ListingStatus.active;

  static ListingStatus fromValue(dynamic v) =>
      v?.toString() == 'paused' ? ListingStatus.paused : ListingStatus.active;
}

enum RequestStatus { pending, accepted, declined, withdrawn }

extension RequestStatusX on RequestStatus {
  String get value {
    switch (this) {
      case RequestStatus.pending:
        return 'pending';
      case RequestStatus.accepted:
        return 'accepted';
      case RequestStatus.declined:
        return 'declined';
      case RequestStatus.withdrawn:
        return 'withdrawn';
    }
  }

  String get label {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.declined:
        return 'Declined';
      case RequestStatus.withdrawn:
        return 'Withdrawn';
    }
  }

  static RequestStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'declined':
        return RequestStatus.declined;
      case 'withdrawn':
        return RequestStatus.withdrawn;
      default:
        return RequestStatus.pending;
    }
  }
}

class SupplierListing {
  final String id;
  final String supplierUid;
  final String supplierName;
  final String? supplierPhoto;
  final String category;
  final String title;
  final String description;

  /// Free-text price info, e.g. "$500/day" or "Contact for a quote".
  final String? priceInfo;
  final String? city;
  final String? region;
  final List<String> imageUrls;
  final ListingStatus status;
  final int requestCount;
  final int? createdAt;
  final int? updatedAt;

  const SupplierListing({
    required this.id,
    this.supplierUid = '',
    this.supplierName = '',
    this.supplierPhoto,
    this.category = '',
    this.title = '',
    this.description = '',
    this.priceInfo,
    this.city,
    this.region,
    this.imageUrls = const [],
    this.status = ListingStatus.active,
    this.requestCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  static List<String> _list(dynamic v) => v is List
      ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
      : const [];

  factory SupplierListing.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      SupplierListing.fromMap(doc.id, doc.data() ?? const {});

  factory SupplierListing.fromMap(String id, Map<String, dynamic> d) {
    return SupplierListing(
      id: id,
      supplierUid: (d['supplierUid'] ?? '').toString(),
      supplierName: (d['supplierName'] ?? '').toString(),
      supplierPhoto: d['supplierPhoto']?.toString(),
      category: (d['category'] ?? '').toString(),
      title: (d['title'] ?? '').toString(),
      description: (d['description'] ?? '').toString(),
      priceInfo: d['priceInfo']?.toString(),
      city: d['city']?.toString(),
      region: d['region']?.toString(),
      imageUrls: _list(d['imageUrls']),
      status: ListingStatusX.fromValue(d['status']),
      requestCount:
          d['requestCount'] is num ? (d['requestCount'] as num).toInt() : 0,
      createdAt: readMillis(d['createdAt']),
      updatedAt: readMillis(d['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'supplierUid': supplierUid,
        'supplierName': supplierName,
        'supplierPhoto': supplierPhoto,
        'category': category,
        'title': title,
        'description': description,
        'priceInfo': priceInfo,
        'city': city,
        'region': region,
        'imageUrls': imageUrls,
        'status': status.value,
        'requestCount': requestCount,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  String get locationLine {
    final parts = <String>[
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
    ];
    return parts.join(' · ');
  }
}

class SupplierRequest {
  final String id;
  final String listingId;
  final String requesterUid;
  final String requesterName;
  final String? requesterPhoto;
  final String message;
  final RequestStatus status;
  final int? createdAt;

  const SupplierRequest({
    required this.id,
    this.listingId = '',
    this.requesterUid = '',
    this.requesterName = '',
    this.requesterPhoto,
    this.message = '',
    this.status = RequestStatus.pending,
    this.createdAt,
  });

  factory SupplierRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return SupplierRequest(
      id: doc.id,
      listingId: (d['listingId'] ?? '').toString(),
      requesterUid: (d['requesterUid'] ?? doc.id).toString(),
      requesterName: (d['requesterName'] ?? '').toString(),
      requesterPhoto: d['requesterPhoto']?.toString(),
      message: (d['message'] ?? '').toString(),
      status: RequestStatusX.fromValue(d['status']),
      createdAt: readMillis(d['createdAt']),
    );
  }
}
