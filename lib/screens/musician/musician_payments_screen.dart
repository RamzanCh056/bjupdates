import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/musician_career_models.dart';
import '../../models/musician_payment_models.dart';
import '../../services/musician_career_service.dart';
import '../../services/musician_payment_service.dart';
import '../../utils/color.dart';

/// Musician-facing payments — a read-only list with a paid / outstanding
/// summary. Mirrors the admin `payments` collection.
class MusicianPaymentsScreen extends StatefulWidget {
  const MusicianPaymentsScreen({super.key});

  @override
  State<MusicianPaymentsScreen> createState() => _MusicianPaymentsScreenState();
}

class _MusicianPaymentsScreenState extends State<MusicianPaymentsScreen> {
  Musician? _musician;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await MusicianCareerService.getMyMusician();
    if (!mounted) return;
    setState(() {
      _musician = m;
      _loading = false;
    });
  }

  String _money(num v, String currency) {
    final f = NumberFormat.currency(
      symbol: _symbol(currency),
      decimalDigits: v.truncateToDouble() == v ? 0 : 2,
    );
    return f.format(v);
  }

  String _symbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'GBP':
        return '£';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Payments',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purpleAccent))
          : _musician == null
              ? _needsProfile()
              : StreamBuilder<List<Payment>>(
                  stream:
                      MusicianPaymentService.watchMyPayments(_musician!.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: purpleAccent));
                    }
                    final payments = snap.data ?? const <Payment>[];
                    if (payments.isEmpty) return _empty();
                    return _list(payments);
                  },
                ),
    );
  }

  Widget _needsProfile() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Register as a musician first to see your payments.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('No payments yet',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Payment records the BeatJerky team adds will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _list(List<Payment> payments) {
    // Summary tiles — group totals by currency, using the most common one.
    final currency =
        payments.isNotEmpty ? payments.first.currency : 'GBP';
    num paid = 0;
    num outstanding = 0;
    for (final p in payments) {
      if (p.status == PaymentStatus.paid) {
        paid += p.amount;
      } else {
        outstanding += p.outstandingAmount;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Row(
          children: [
            _summaryTile('Paid', _money(paid, currency), greenColor),
            const SizedBox(width: 12),
            _summaryTile(
                'Outstanding', _money(outstanding, currency), peopleColor),
          ],
        ),
        const SizedBox(height: 18),
        ...payments.map(_paymentCard),
      ],
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(Payment p) {
    final title = p.gigName?.isNotEmpty == true
        ? p.gigName!
        : (p.client?.isNotEmpty == true ? p.client! : 'Payment');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    if ((p.client ?? '').isNotEmpty &&
                        p.gigName?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(p.client!,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_money(p.amount, p.currency),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _statusPill(p.status),
              const Spacer(),
              if (p.dueDate != null && p.status != PaymentStatus.paid)
                Text('Due ${_date(p.dueDate!)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
              if (p.paidDate != null && p.status == PaymentStatus.paid)
                Text('Paid ${_date(p.paidDate!)}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
            ],
          ),
          if ((p.method ?? '').isNotEmpty || p.deposit != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if ((p.method ?? '').isNotEmpty) 'Method: ${p.method}',
                if (p.deposit != null)
                  'Deposit: ${_money(p.deposit!, p.currency)}',
              ].join('  ·  '),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
          if ((p.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.notes!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.35)),
          ],
          if ((p.receiptUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openUrl(p.receiptUrl!),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.receipt_long, size: 16, color: purpleAccent),
                  SizedBox(width: 6),
                  Text('View receipt',
                      style: TextStyle(
                          color: purpleAccent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _date(int ms) =>
      DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));

  Widget _statusPill(PaymentStatus status) {
    Color c;
    switch (status) {
      case PaymentStatus.paid:
        c = greenColor;
        break;
      case PaymentStatus.partiallyPaid:
        c = eventsColor;
        break;
      case PaymentStatus.pending:
        c = peopleColor;
        break;
      case PaymentStatus.overdue:
        c = redColor;
        break;
      case PaymentStatus.cancelled:
        c = greyColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(status.label,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
