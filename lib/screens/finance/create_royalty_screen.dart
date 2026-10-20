import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/invoice_models.dart' show DocStatus, DocStatusX;
import '../../models/royalty_models.dart';
import '../../services/royalty_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../utils/name_utils.dart';
import '../../utils/pro_profile_utils.dart';
import '../../utils/role_utils.dart';

class _TrackRow {
  final TextEditingController title;
  final TextEditingController isrc;
  final TextEditingController upc;
  final TextEditingController units;
  final TextEditingController gross;
  _TrackRow({String t = '', String i = '', String u = '', String un = '', String g = ''})
      : title = TextEditingController(text: t),
        isrc = TextEditingController(text: i),
        upc = TextEditingController(text: u),
        units = TextEditingController(text: un),
        gross = TextEditingController(text: g);
  void dispose() {
    title.dispose();
    isrc.dispose();
    upc.dispose();
    units.dispose();
    gross.dispose();
  }

  num get grossVal => num.tryParse(gross.text.trim()) ?? 0;
}

class CreateRoyaltyScreen extends StatefulWidget {
  final RoyaltyStatement? existing;
  const CreateRoyaltyScreen({super.key, this.existing});

  @override
  State<CreateRoyaltyScreen> createState() => _CreateRoyaltyScreenState();
}

class _CreateRoyaltyScreenState extends State<CreateRoyaltyScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  final _artist = TextEditingController();
  final _period = TextEditingController();
  final _deductions = TextEditingController();
  final _notes = TextEditingController();
  final List<_TrackRow> _tracks = [];
  String? _artistUid;
  DocStatus _status = DocStatus.draft;
  bool _saving = false;
  String _labelName = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _artist.text = e.artistName;
      _artistUid = e.artistUid;
      _period.text = e.period;
      _deductions.text = e.deductions == 0 ? '' : e.deductions.toString();
      _notes.text = e.notes;
      _status = e.status;
      _labelName = e.labelName;
      for (final t in e.tracks) {
        _tracks.add(_TrackRow(
            t: t.title,
            i: t.isrc,
            u: t.upc,
            un: t.units.toString(),
            g: t.gross.toString()));
      }
    }
    if (_tracks.isEmpty) _tracks.add(_TrackRow());
    _loadLabel();
  }

  @override
  void dispose() {
    _artist.dispose();
    _period.dispose();
    _deductions.dispose();
    _notes.dispose();
    for (final t in _tracks) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLabel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final pro = proProfileForRole(data, RoleKeys.label) ?? const {};
      final orgName = (pro['orgName'] ?? '').toString().trim();
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      if (!mounted) return;
      if (_labelName.isEmpty) {
        setState(() => _labelName = orgName.isNotEmpty
            ? orgName
            : [first, last].where((s) => s.isNotEmpty).join(' '));
      }
    } catch (_) {}
  }

  num get _grossTotal => _tracks.fold<num>(0, (a, b) => a + b.grossVal);
  num get _deductionsVal => num.tryParse(_deductions.text.trim()) ?? 0;
  num get _net => _grossTotal - _deductionsVal;
  String _m(num v) => '\$${v.toStringAsFixed(2)}';

  Future<void> _pickArtist() async {
    final picked = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: darkBackgroundPrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ArtistPicker(),
    );
    if (picked != null) {
      setState(() {
        _artistUid = picked['uid'];
        _artist.text = picked['name'] ?? _artist.text;
      });
    }
  }

  Future<void> _submit() async {
    if (_artist.text.trim().isEmpty) {
      AppToast.show('Add the artist name', isError: true);
      return;
    }
    setState(() => _saving = true);
    final tracks = _tracks
        .where((t) => t.title.text.trim().isNotEmpty || t.grossVal > 0)
        .map((t) => RoyaltyTrack(
              title: t.title.text.trim(),
              isrc: t.isrc.text.trim(),
              upc: t.upc.text.trim(),
              units: num.tryParse(t.units.text.trim()) ?? 0,
              gross: t.grossVal,
            ))
        .toList();
    final st = RoyaltyStatement(
      id: widget.existing?.id ?? '',
      labelUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      labelName: _labelName,
      artistUid: _artistUid,
      artistName: _artist.text.trim(),
      period: _period.text.trim(),
      tracks: tracks,
      deductions: _deductionsVal,
      notes: _notes.text.trim(),
      status: _status,
    );
    final ok = widget.existing == null
        ? (await RoyaltyService.create(st)) != null
        : await RoyaltyService.update(widget.existing!.id, st);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppToast.show(widget.existing == null ? 'Statement saved' : 'Statement updated');
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
        title: Text(
            widget.existing == null ? 'New statement' : 'Edit statement',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _field(_artist, 'Artist name', Icons.person_outline),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _pickArtist,
              icon: Icon(
                  _artistUid != null ? Icons.link : Icons.link_outlined,
                  size: 16,
                  color: _accent),
              label: Text(
                  _artistUid != null
                      ? 'Linked to app user ✓'
                      : 'Link to app user (so they can view it)',
                  style: const TextStyle(color: _accent, fontSize: 12.5)),
            ),
          ),
          const SizedBox(height: 8),
          _field(_period, 'Period (e.g. Q1 2026)', Icons.date_range),
          const SizedBox(height: 22),
          _label('Tracks'),
          const SizedBox(height: 10),
          ..._tracks.asMap().entries.map((e) => _trackRow(e.key)),
          TextButton.icon(
            onPressed: () => setState(() => _tracks.add(_TrackRow())),
            icon: const Icon(Icons.add, color: _accent, size: 18),
            label: const Text('Add track',
                style: TextStyle(color: _accent, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          _field(_deductions, 'Deductions (optional)', Icons.remove_circle_outline,
              number: true, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
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
                  : Text(
                      widget.existing == null
                          ? 'Save statement'
                          : 'Save changes',
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

  Widget _trackRow(int i) {
    final t = _tracks[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Row(children: [
            Expanded(child: _field(t.title, 'Track title', Icons.music_note)),
            if (_tracks.length > 1)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 18),
                onPressed: () => setState(() => _tracks.removeAt(i).dispose()),
              ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(t.isrc, 'ISRC', Icons.qr_code)),
            const SizedBox(width: 8),
            Expanded(child: _field(t.upc, 'UPC', Icons.qr_code_2)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _field(t.units, 'Units', Icons.numbers, number: true)),
            const SizedBox(width: 8),
            Expanded(
                child: _field(t.gross, 'Gross', Icons.attach_money,
                    number: true, onChanged: (_) => setState(() {}))),
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
        row('Gross total', _m(_grossTotal)),
        row('Deductions', '- ${_m(_deductionsVal)}'),
        const Divider(color: Colors.white12),
        row('Net payable', _m(_net), bold: true),
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

/// Simple user picker: search app users by name, returns {uid, name}.
class _ArtistPicker extends StatefulWidget {
  const _ArtistPicker();

  @override
  State<_ArtistPicker> createState() => _ArtistPickerState();
}

class _ArtistPickerState extends State<_ArtistPicker> {
  static const Color _accent = Color(0xFFBB86FC);
  final _search = TextEditingController();
  List<Map<String, String>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usersData')
          .limit(400)
          .get();
      final me = FirebaseAuth.instance.currentUser?.uid;
      _all = snap.docs
          .where((d) => d.id != me)
          .map((d) {
            final data = d.data();
            final name = NameUtils.getDisplayNameSafe(
              data['firstName']?.toString(),
              data['secondName']?.toString(),
              fallback: data['displayName']?.toString() ?? 'User',
            );
            return {'uid': d.id, 'name': name};
          })
          .toList();
    } catch (_) {
      _all = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final list = q.isEmpty
        ? _all
        : _all.where((e) => e['name']!.toLowerCase().contains(q)).toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Link artist',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by name',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _accent))
                : list.isEmpty
                    ? const Center(
                        child: Text('No users found',
                            style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person,
                                color: Colors.white, size: 18),
                          ),
                          title: Text(list[i]['name']!,
                              style: const TextStyle(color: Colors.white)),
                          onTap: () => Navigator.pop(context, list[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
