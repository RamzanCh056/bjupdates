import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/invoice_models.dart' show DocStatus, DocStatusX;
import '../../models/royalty_models.dart';
import '../../services/royalty_service.dart';
import '../../services/pdf_service.dart';
import '../../widgets/doc_actions_bar.dart';
import '../../utils/color.dart';
import 'create_royalty_screen.dart';

class RoyaltyDetailScreen extends StatelessWidget {
  final RoyaltyStatement statement;
  const RoyaltyDetailScreen({super.key, required this.statement});

  static const Color _accent = Color(0xFFBB86FC);
  String _m(num v) => '\$${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isLabel = uid != null && uid == statement.labelUid;
    final safeName = 'Statement_${statement.period.isEmpty ? statement.id : statement.period}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      bottomNavigationBar: DocActionsBar(
        fileName: safeName,
        buildPdf: () => PdfService.royalty(statement),
      ),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        centerTitle: true,
        title: const Text('Statement',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        actions: [
          if (isLabel)
            PopupMenuButton<String>(
              iconColor: Colors.white,
              color: const Color(0xFF2A2A33),
              onSelected: (v) async {
                switch (v) {
                  case 'edit':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CreateRoyaltyScreen(existing: statement)));
                    break;
                  case 'draft':
                    await RoyaltyService.setStatus(
                        statement.id, DocStatus.draft);
                    break;
                  case 'sent':
                    await RoyaltyService.setStatus(
                        statement.id, DocStatus.sent);
                    break;
                  case 'paid':
                    await RoyaltyService.setStatus(
                        statement.id, DocStatus.paid);
                    break;
                  case 'delete':
                    final ok = await RoyaltyService.delete(statement.id);
                    if (ok && context.mounted) Navigator.pop(context);
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'draft', child: Text('Mark draft')),
                PopupMenuItem(value: 'sent', child: Text('Mark sent')),
                PopupMenuItem(value: 'paid', child: Text('Mark paid')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: StreamBuilder<RoyaltyStatement?>(
        stream: RoyaltyService.watchOne(statement.id),
        initialData: statement,
        builder: (context, snap) {
          final st = snap.data ?? statement;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          st.period.isEmpty
                              ? 'Royalty statement'
                              : st.period,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${st.labelName} → ${st.artistName}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                _statusPill(st.status),
              ]),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Row(children: const [
                    Expanded(
                        flex: 5,
                        child: Text('Track',
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11.5))),
                    Expanded(
                        flex: 2,
                        child: Text('Units',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11.5))),
                    Expanded(
                        flex: 2,
                        child: Text('Gross',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: Colors.white54, fontSize: 11.5))),
                  ]),
                  const Divider(color: Colors.white12),
                  ...st.tracks.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  flex: 5,
                                  child: Text(
                                      t.title.isEmpty ? '—' : t.title,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13))),
                              Expanded(
                                  flex: 2,
                                  child: Text('${t.units}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13))),
                              Expanded(
                                  flex: 2,
                                  child: Text(_m(t.gross),
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13))),
                            ]),
                            if (t.isrc.isNotEmpty || t.upc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                    [
                                      if (t.isrc.isNotEmpty) 'ISRC ${t.isrc}',
                                      if (t.upc.isNotEmpty) 'UPC ${t.upc}',
                                    ].join('  ·  '),
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11)),
                              ),
                          ],
                        ),
                      )),
                ]),
              ),
              const SizedBox(height: 14),
              _totals(st),
              if (st.notes.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Notes',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(st.notes,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 13.5)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _statusPill(DocStatus s) {
    Color c = s == DocStatus.paid
        ? Colors.green
        : s == DocStatus.sent
            ? const Color(0xFF38bdf8)
            : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
      child: Text(s.label,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _totals(RoyaltyStatement st) {
    Widget row(String k, String v, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(k,
                style: TextStyle(
                    color: bold ? Colors.white : Colors.white70,
                    fontSize: bold ? 15 : 13.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
            const Spacer(),
            Text(v,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: bold ? 17 : 13.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    return Column(children: [
      row('Gross total', _m(st.grossTotal)),
      row('Deductions', '- ${_m(st.deductions)}'),
      const Divider(color: Colors.white12),
      row('Net (${st.currency})', _m(st.net), bold: true),
    ]);
  }
}
