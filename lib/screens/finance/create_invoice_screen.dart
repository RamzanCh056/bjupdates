import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/invoice_models.dart';
import '../../services/invoice_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../utils/pro_profile_utils.dart';
import '../../utils/role_utils.dart';

class _ItemRow {
  final TextEditingController desc;
  final TextEditingController qty;
  final TextEditingController rate;
  _ItemRow({String d = '', String q = '1', String r = ''})
      : desc = TextEditingController(text: d),
        qty = TextEditingController(text: q),
        rate = TextEditingController(text: r);
  void dispose() {
    desc.dispose();
    qty.dispose();
    rate.dispose();
  }

  num get lineTotal =>
      (num.tryParse(qty.text.trim()) ?? 0) * (num.tryParse(rate.text.trim()) ?? 0);
}

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? existing;
  const CreateInvoiceScreen({super.key, this.existing});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  final _client = TextEditingController();
  final _number = TextEditingController();
  final _notes = TextEditingController();
  final _gst = TextEditingController(text: kGstRate.toString());
  final _qst = TextEditingController(text: kQstRate.toString());
  final List<_ItemRow> _items = [];
  DateTime _issueDate = DateTime.now();
  DocStatus _status = DocStatus.draft;
  bool _saving = false;
  String _djName = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _client.text = e.clientName;
      _number.text = e.number;
      _notes.text = e.notes;
      _gst.text = e.gstRate.toString();
      _qst.text = e.qstRate.toString();
      _status = e.status;
      _issueDate = e.issueDateTime ?? DateTime.now();
      _djName = e.djName;
      for (final it in e.items) {
        _items.add(_ItemRow(
            d: it.description,
            q: it.qty.toString(),
            r: it.rate.toString()));
      }
    }
    if (_items.isEmpty) _items.add(_ItemRow());
    if (_number.text.isEmpty) {
      final now = DateTime.now();
      _number.text =
          'INV-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 1000}';
    }
    _loadDj();
  }

  @override
  void dispose() {
    _client.dispose();
    _number.dispose();
    _notes.dispose();
    _gst.dispose();
    _qst.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDj() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final pro = proProfileForRole(data, RoleKeys.dj) ?? const {};
      final stage = (pro['stageName'] ?? '').toString().trim();
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      if (!mounted) return;
      if (_djName.isEmpty) {
        setState(() => _djName =
            stage.isNotEmpty ? stage : [first, last].where((s) => s.isNotEmpty).join(' '));
      }
    } catch (_) {}
  }

  num get _subtotal => _items.fold<num>(0, (a, b) => a + b.lineTotal);
  double get _gstRate => double.tryParse(_gst.text.trim()) ?? 0;
  double get _qstRate => double.tryParse(_qst.text.trim()) ?? 0;
  num get _gstAmt => _subtotal * _gstRate / 100;
  num get _qstAmt => _subtotal * _qstRate / 100;
  num get _total => _subtotal + _gstAmt + _qstAmt;

  String _m(num v) => '\$${v.toStringAsFixed(2)}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
              primary: _accent, surface: darkBackgroundPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _issueDate = picked);
  }

  Future<void> _submit() async {
    if (_client.text.trim().isEmpty) {
      AppToast.show('Add a client name', isError: true);
      return;
    }
    setState(() => _saving = true);
    final items = _items
        .where((i) => i.desc.text.trim().isNotEmpty || i.lineTotal > 0)
        .map((i) => InvoiceItem(
              description: i.desc.text.trim(),
              qty: num.tryParse(i.qty.text.trim()) ?? 0,
              rate: num.tryParse(i.rate.text.trim()) ?? 0,
            ))
        .toList();
    final inv = Invoice(
      id: widget.existing?.id ?? '',
      djUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      djName: _djName,
      clientName: _client.text.trim(),
      items: items,
      gstRate: _gstRate,
      qstRate: _qstRate,
      number: _number.text.trim(),
      issueDate: _issueDate.millisecondsSinceEpoch,
      notes: _notes.text.trim(),
      status: _status,
    );
    final ok = widget.existing == null
        ? (await InvoiceService.create(inv)) != null
        : await InvoiceService.update(widget.existing!.id, inv);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppToast.show(widget.existing == null ? 'Invoice saved' : 'Invoice updated');
      Navigator.pop(context, true);
    } else {
      AppToast.show('Could not save. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.existing == null ? 'New invoice' : 'Edit invoice',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _field(_client, 'Client / payer name', Icons.person_outline),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(_number, 'Invoice #', Icons.tag)),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    Icon(Icons.event, color: _accent.withOpacity(0.7), size: 20),
                    const SizedBox(width: 8),
                    Text(
                        '${_issueDate.day}/${_issueDate.month}/${_issueDate.year}',
                        style: const TextStyle(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 22),
          _label('Line items'),
          const SizedBox(height: 10),
          ..._items.asMap().entries.map((e) => _itemRow(e.key)),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _items.add(_ItemRow())),
            icon: const Icon(Icons.add, color: _accent, size: 18),
            label: const Text('Add item',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(_gst, 'GST %', Icons.percent,
                    number: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(
                child: _field(_qst, 'QST %', Icons.percent,
                    number: true, onChanged: (_) => setState(() {}))),
          ]),
          const SizedBox(height: 16),
          _totalsCard(),
          const SizedBox(height: 16),
          _field(_notes, 'Notes (optional)', Icons.notes, maxLines: 2),
          const SizedBox(height: 16),
          _label('Status'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: DocStatus.values.map((s) {
              final sel = _status == s;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _status = s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _accent : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _accent : Colors.white24),
                  ),
                  child: Text(s.label,
                      style: TextStyle(
                          color: sel ? Colors.black : Colors.white,
                          fontSize: 13,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : Text(widget.existing == null ? 'Save invoice' : 'Save changes',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700));

  Widget _itemRow(int i) {
    final row = _items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          _field(row.desc, 'Description', Icons.short_text),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field(row.qty, 'Qty', Icons.numbers,
                    number: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: _field(row.rate, 'Rate', Icons.attach_money,
                    number: true, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: Text(_m(row.lineTotal),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            if (_items.length > 1)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => setState(() {
                  _items.removeAt(i).dispose();
                }),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _totalsCard() {
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
                    fontSize: bold ? 16 : 13.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        row('Subtotal', _m(_subtotal)),
        row('GST (${_gstRate.toStringAsFixed(_gstRate % 1 == 0 ? 0 : 3)}%)', _m(_gstAmt)),
        row('QST (${_qstRate.toStringAsFixed(_qstRate % 1 == 0 ? 0 : 3)}%)', _m(_qstAmt)),
        const Divider(color: Colors.white12),
        row('Total', _m(_total), bold: true),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool number = false,
      int maxLines = 1,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: _accent.withOpacity(0.7), size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
