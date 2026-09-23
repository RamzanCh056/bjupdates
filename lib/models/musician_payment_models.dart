import 'package:cloud_firestore/cloud_firestore.dart';

import 'musician_career_models.dart'
    show readMillis, PaymentStatus, PaymentStatusX;

/// Payment record for the Musician-Career feature — mirrors the admin schema
/// (`beatjerky-admin/src/lib/types.ts` → Payment). Read-only in the app.
/// Timestamps are int-milliseconds.
class Payment {
  final String id;
  final String musicianId;
  final String? gigName;
  final String? client;
  final num amount;
  final String currency;
  final String? method;
  final PaymentStatus status;
  final int? dueDate;
  final int? paidDate;
  final num? deposit;
  final num? expenses;
  final String? receiptUrl;
  final String? notes;
  final int? createdAt;

  const Payment({
    required this.id,
    required this.musicianId,
    this.gigName,
    this.client,
    this.amount = 0,
    this.currency = 'GBP',
    this.method,
    this.status = PaymentStatus.pending,
    this.dueDate,
    this.paidDate,
    this.deposit,
    this.expenses,
    this.receiptUrl,
    this.notes,
    this.createdAt,
  });

  factory Payment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Payment.fromMap(doc.id, doc.data() ?? const {});

  factory Payment.fromMap(String id, Map<String, dynamic> data) {
    return Payment(
      id: id,
      musicianId: (data['musicianId'] ?? '').toString(),
      gigName: data['gigName']?.toString(),
      client: data['client']?.toString(),
      amount: data['amount'] is num ? data['amount'] as num : 0,
      currency: (data['currency'] ?? 'GBP').toString(),
      method: data['method']?.toString(),
      status: PaymentStatusX.fromValue(data['status']),
      dueDate: readMillis(data['dueDate']),
      paidDate: readMillis(data['paidDate']),
      deposit: data['deposit'] is num ? data['deposit'] as num : null,
      expenses: data['expenses'] is num ? data['expenses'] as num : null,
      receiptUrl: data['receiptUrl']?.toString(),
      notes: data['notes']?.toString(),
      createdAt: readMillis(data['createdAt']),
    );
  }

  /// True when money is still owed (not fully paid or cancelled).
  bool get isOutstanding =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.partiallyPaid ||
      status == PaymentStatus.overdue;

  /// Amount still owed after any recorded deposit (best-effort, for summaries).
  num get outstandingAmount {
    if (status == PaymentStatus.paid || status == PaymentStatus.cancelled) {
      return 0;
    }
    final dep = deposit ?? 0;
    final rem = amount - dep;
    return rem < 0 ? 0 : rem;
  }
}
