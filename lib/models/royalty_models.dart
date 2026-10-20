import 'package:cloud_firestore/cloud_firestore.dart';

import 'invoice_models.dart' show DocStatus, DocStatusX;
import 'musician_career_models.dart' show readMillis;

class RoyaltyTrack {
  final String title;
  final String isrc;
  final String upc;
  final num units;
  final num gross;

  const RoyaltyTrack({
    this.title = '',
    this.isrc = '',
    this.upc = '',
    this.units = 0,
    this.gross = 0,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'isrc': isrc,
        'upc': upc,
        'units': units,
        'gross': gross,
      };

  factory RoyaltyTrack.fromMap(Map<String, dynamic> m) => RoyaltyTrack(
        title: (m['title'] ?? '').toString(),
        isrc: (m['isrc'] ?? '').toString(),
        upc: (m['upc'] ?? '').toString(),
        units: m['units'] is num ? m['units'] as num : 0,
        gross: m['gross'] is num ? m['gross'] as num : 0,
      );
}

/// A label-to-artist royalty statement.
class RoyaltyStatement {
  final String id;
  final String labelUid;
  final String labelName;
  final String? artistUid;
  final String artistName;
  final String period;
  final List<RoyaltyTrack> tracks;
  final num deductions;
  final String currency;
  final String notes;
  final DocStatus status;
  final int? createdAt;

  const RoyaltyStatement({
    required this.id,
    this.labelUid = '',
    this.labelName = '',
    this.artistUid,
    this.artistName = '',
    this.period = '',
    this.tracks = const [],
    this.deductions = 0,
    this.currency = 'CAD',
    this.notes = '',
    this.status = DocStatus.draft,
    this.createdAt,
  });

  num get grossTotal => tracks.fold<num>(0, (a, b) => a + b.gross);
  num get totalUnits => tracks.fold<num>(0, (a, b) => a + b.units);
  num get net => grossTotal - deductions;

  factory RoyaltyStatement.fromDoc(
          DocumentSnapshot<Map<String, dynamic>> doc) =>
      RoyaltyStatement.fromMap(doc.id, doc.data() ?? const {});

  factory RoyaltyStatement.fromMap(String id, Map<String, dynamic> d) {
    return RoyaltyStatement(
      id: id,
      labelUid: (d['labelUid'] ?? '').toString(),
      labelName: (d['labelName'] ?? '').toString(),
      artistUid: d['artistUid']?.toString(),
      artistName: (d['artistName'] ?? '').toString(),
      period: (d['period'] ?? '').toString(),
      tracks: (d['tracks'] is List)
          ? (d['tracks'] as List)
              .whereType<Map>()
              .map((m) => RoyaltyTrack.fromMap(m.cast<String, dynamic>()))
              .toList()
          : const [],
      deductions: d['deductions'] is num ? d['deductions'] as num : 0,
      currency: (d['currency'] ?? 'CAD').toString(),
      notes: (d['notes'] ?? '').toString(),
      status: DocStatusX.fromValue(d['status']),
      createdAt: readMillis(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'labelUid': labelUid,
        'labelName': labelName,
        'artistUid': artistUid,
        'artistName': artistName,
        'period': period,
        'tracks': tracks.map((e) => e.toMap()).toList(),
        'deductions': deductions,
        'currency': currency,
        'notes': notes,
        'status': status.value,
        'grossTotal': grossTotal,
        'net': net,
        'createdAt': createdAt,
      };
}
