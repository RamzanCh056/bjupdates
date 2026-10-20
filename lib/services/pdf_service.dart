import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:beatjerky/models/invoice_models.dart';
import 'package:beatjerky/models/royalty_models.dart';

/// Builds printable / shareable PDFs for invoices and royalty statements.
class PdfService {
  PdfService._();

  static const PdfColor _accent = PdfColor.fromInt(0xFF7C3AED);
  static const PdfColor _muted = PdfColor.fromInt(0xFF666666);

  static String _m(num v) => '\$${v.toStringAsFixed(2)}';

  static String _date(DateTime? d) =>
      d == null ? '-' : '${d.day}/${d.month}/${d.year}';

  static pw.Widget _totalsRow(String k, String v, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k,
              style: pw.TextStyle(
                  fontSize: bold ? 12 : 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(v,
              style: pw.TextStyle(
                  fontSize: bold ? 13 : 10,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<Uint8List> invoice(Invoice inv) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: _accent)),
                  pw.SizedBox(height: 2),
                  pw.Text(inv.number, style: const pw.TextStyle(fontSize: 11)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(inv.djName.isEmpty ? '' : inv.djName,
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Date: ${_date(inv.issueDateTime)}',
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
                  pw.Text('Status: ${inv.status.label}',
                      style: const pw.TextStyle(fontSize: 10, color: _muted)),
                ]),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text('Billed to',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Text(inv.clientName.isEmpty ? '-' : inv.clientName,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _accent),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              headers: ['Item', 'Qty', 'Rate', 'Amount'],
              data: inv.items
                  .map((it) => [
                        it.description,
                        '${it.qty}',
                        _m(it.rate),
                        _m(it.total),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  _totalsRow('Subtotal', _m(inv.subtotal)),
                  _totalsRow('GST (${inv.gstRate}%)', _m(inv.gst)),
                  _totalsRow('QST (${inv.qstRate}%)', _m(inv.qst)),
                  pw.Divider(),
                  _totalsRow('Total (${inv.currency})', _m(inv.total),
                      bold: true),
                ]),
              ),
            ),
            if (inv.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text('Notes',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(inv.notes, style: const pw.TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> royalty(RoyaltyStatement st) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ROYALTY STATEMENT',
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent)),
            pw.SizedBox(height: 2),
            pw.Text(st.period.isEmpty ? '' : st.period,
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 10),
            pw.Text('${st.labelName}  ->  ${st.artistName}',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text('Status: ${st.status.label}',
                style: const pw.TextStyle(fontSize: 10, color: _muted)),
            pw.SizedBox(height: 18),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _accent),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
              },
              headers: ['Track', 'ISRC', 'UPC', 'Units', 'Gross'],
              data: st.tracks
                  .map((t) => [
                        t.title,
                        t.isrc,
                        t.upc,
                        '${t.units}',
                        _m(t.gross),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  _totalsRow('Gross total', _m(st.grossTotal)),
                  _totalsRow('Deductions', '- ${_m(st.deductions)}'),
                  pw.Divider(),
                  _totalsRow('Net (${st.currency})', _m(st.net), bold: true),
                ]),
              ),
            ),
            if (st.notes.trim().isNotEmpty) ...[
              pw.SizedBox(height: 18),
              pw.Text('Notes',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
              pw.Text(st.notes, style: const pw.TextStyle(fontSize: 10)),
            ],
          ],
        ),
      ),
    );
    return doc.save();
  }
}
