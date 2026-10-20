import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart' show readMillis;

/// Status shared by invoices and royalty statements.
enum DocStatus { draft, sent, paid }

extension DocStatusX on DocStatus {
  String get value {
    switch (this) {
      case DocStatus.draft:
        return 'draft';
      case DocStatus.sent:
        return 'sent';
      case DocStatus.paid:
        return 'paid';
    }
  }

  String get label {
    switch (this) {
      case DocStatus.draft:
        return 'Draft';
      case DocStatus.sent:
        return 'Sent';
      case DocStatus.paid:
        return 'Paid';
    }
  }

  static DocStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'sent':
        return DocStatus.sent;
      case 'paid':
        return DocStatus.paid;
      default:
        return DocStatus.draft;
    }
  }
}

/// Quebec default tax rates.
const double kGstRate = 5.0;
const double kQstRate = 9.975;

class InvoiceItem {
  final String description;
  final num qty;
  final num rate;

  const InvoiceItem({this.description = '', this.qty = 1, this.rate = 0});

  num get total => qty * rate;

  Map<String, dynamic> toMap() =>
      {'description': description, 'qty': qty, 'rate': rate};

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        description: (m['description'] ?? '').toString(),
        qty: m['qty'] is num ? m['qty'] as num : 1,
        rate: m['rate'] is num ? m['rate'] as num : 0,
      );
}

/// A DJ performance invoice with GST/QST and automatic totals.
class Invoice {
  final String id;
  final String djUid;
  final String djName;
  final String clientName;
  final List<InvoiceItem> items;
  final double gstRate;
  final double qstRate;
  final String currency;
  final String number;
  final int? issueDate;
  final String notes;
  final DocStatus status;
  final int? createdAt;

  const Invoice({
    required this.id,
    this.djUid = '',
    this.djName = '',
    this.clientName = '',
    this.items = const [],
    this.gstRate = kGstRate,
    this.qstRate = kQstRate,
    this.currency = 'CAD',
    this.number = '',
    this.issueDate,
    this.notes = '',
    this.status = DocStatus.draft,
    this.createdAt,
  });

  num get subtotal => items.fold<num>(0, (a, b) => a + b.total);
  num get gst => subtotal * gstRate / 100;
  num get qst => subtotal * qstRate / 100;
  num get total => subtotal + gst + qst;

  factory Invoice.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Invoice.fromMap(doc.id, doc.data() ?? const {});

  factory Invoice.fromMap(String id, Map<String, dynamic> d) {
    return Invoice(
      id: id,
      djUid: (d['djUid'] ?? '').toString(),
      djName: (d['djName'] ?? '').toString(),
      clientName: (d['clientName'] ?? '').toString(),
      items: (d['items'] is List)
          ? (d['items'] as List)
              .whereType<Map>()
              .map((m) => InvoiceItem.fromMap(m.cast<String, dynamic>()))
              .toList()
          : const [],
      gstRate: (d['gstRate'] is num) ? (d['gstRate'] as num).toDouble() : kGstRate,
      qstRate: (d['qstRate'] is num) ? (d['qstRate'] as num).toDouble() : kQstRate,
      currency: (d['currency'] ?? 'CAD').toString(),
      number: (d['number'] ?? '').toString(),
      issueDate: readMillis(d['issueDate']),
      notes: (d['notes'] ?? '').toString(),
      status: DocStatusX.fromValue(d['status']),
      createdAt: readMillis(d['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'djUid': djUid,
        'djName': djName,
        'clientName': clientName,
        'items': items.map((e) => e.toMap()).toList(),
        'gstRate': gstRate,
        'qstRate': qstRate,
        'currency': currency,
        'number': number,
        'issueDate': issueDate,
        'notes': notes,
        'status': status.value,
        'subtotal': subtotal,
        'gst': gst,
        'qst': qst,
        'total': total,
        'createdAt': createdAt,
      };

  DateTime? get issueDateTime =>
      issueDate == null ? null : DateTime.fromMillisecondsSinceEpoch(issueDate!);
}
