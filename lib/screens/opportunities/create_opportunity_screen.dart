import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/opportunity_models.dart';
import '../../services/opportunity_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../utils/pro_profile_utils.dart';
import '../../utils/role_utils.dart';
import '../bjai_screen.dart';

/// Create or edit a public opportunity post. Only organization-type accounts
/// should reach this screen (the board gates the entry point).
class CreateOpportunityScreen extends StatefulWidget {
  final Opportunity? existing;

  /// Recruitment: link this post to an event and prefill from it.
  final String? eventId;
  final String? eventName;
  final String? prefillTitle;
  final String? prefillCity;
  final DateTime? prefillDate;

  const CreateOpportunityScreen({
    super.key,
    this.existing,
    this.eventId,
    this.eventName,
    this.prefillTitle,
    this.prefillCity,
    this.prefillDate,
  });

  @override
  State<CreateOpportunityScreen> createState() =>
      _CreateOpportunityScreenState();
}

class _CreateOpportunityScreenState extends State<CreateOpportunityScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _postalController = TextEditingController();
  final _budgetController = TextEditingController();

  final Set<String> _rolesWanted = <String>{};
  DateTime? _startDate;
  bool _saving = false;

  // Resolved poster identity / org role.
  String _postedByName = '';
  String? _postedByPhoto;
  String? _orgRole;
  Map<String, dynamic> _data = const {};
  List<String> _orgRoles = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = e.title;
      _descController.text = e.description;
      _cityController.text = e.city ?? '';
      _regionController.text = e.region ?? '';
      _postalController.text = e.postalCode ?? '';
      _budgetController.text = e.budget?.toString() ?? '';
      _rolesWanted.addAll(e.rolesWanted);
      _startDate = e.startDate;
      _postedByName = e.postedByName;
      _postedByPhoto = e.postedByPhoto;
      _orgRole = e.orgRole;
    } else {
      if ((widget.prefillTitle ?? '').isNotEmpty) {
        _titleController.text = widget.prefillTitle!;
      }
      if ((widget.prefillCity ?? '').isNotEmpty) {
        _cityController.text = widget.prefillCity!;
      }
      _startDate ??= widget.prefillDate;
    }
    _loadPoster();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _postalController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadPoster() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      _data = data;
      final roles = parseRolesFromUserData(data);
      _orgRoles = roles.where(isOrganizationRole).toList();
      final want = (_orgRole != null && _orgRoles.contains(_orgRole))
          ? _orgRole!
          : (_orgRoles.isNotEmpty ? _orgRoles.first : '');
      if (!mounted) return;
      if (want.isNotEmpty) {
        // On a new post set the name from the role; on edit keep the saved one.
        _applyPosterRole(want, updateName: widget.existing == null);
      } else {
        final first = (data['firstName'] ?? '').toString().trim();
        final last = (data['secondName'] ?? '').toString().trim();
        final fallbackName =
            [first, last].where((s) => s.isNotEmpty).join(' ');
        setState(() {
          if (_postedByName.isEmpty) _postedByName = fallbackName;
          _postedByPhoto ??= data['profileImage']?.toString();
        });
      }
    } catch (_) {
      // Non-fatal: poster identity is best-effort.
    }
  }

  /// Switch the identity this opportunity is posted under to [role].
  void _applyPosterRole(String role, {bool updateName = true}) {
    final pro = proProfileForRole(_data, role) ?? const {};
    final orgName = (pro['orgName'] ?? '').toString().trim();
    final first = (_data['firstName'] ?? '').toString().trim();
    final last = (_data['secondName'] ?? '').toString().trim();
    final fallbackName = [first, last].where((s) => s.isNotEmpty).join(' ');
    setState(() {
      _orgRole = role;
      _postedByPhoto ??= _data['profileImage']?.toString();
      if (updateName) {
        _postedByName = orgName.isNotEmpty ? orgName : fallbackName;
      } else if (_postedByName.isEmpty) {
        _postedByName = orgName.isNotEmpty ? orgName : fallbackName;
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: darkBackgroundPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _openAiAssist() {
    final title = _titleController.text.trim();
    final roles = _rolesWanted.map(roleDisplayLabel).join(', ');
    final city = _cityController.text.trim();
    final parts = <String>[];
    if (roles.isNotEmpty) parts.add('role(s): $roles');
    if (city.isNotEmpty) parts.add('in $city');
    final ctx = parts.isEmpty ? '' : ' (${parts.join(', ')})';
    final titlePart = title.isEmpty ? 'a music gig' : '"$title"';
    final prompt =
        'Write a short, appealing opportunity post to hire for $titlePart$ctx. '
        'Keep it to 3-4 friendly, professional sentences that a performer would '
        'want to apply to.';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BJAI(initialPrompt: prompt)),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rolesWanted.isEmpty) {
      AppToast.show('Pick at least one role you are looking for',
          isError: true);
      return;
    }
    setState(() => _saving = true);

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final city = _cityController.text.trim();
    final region = _regionController.text.trim();
    final postal = _postalController.text.trim();
    final budget = num.tryParse(_budgetController.text.trim());
    final startAt = _startDate?.millisecondsSinceEpoch;

    bool ok;
    if (widget.existing == null) {
      final id = await OpportunityService.createOpportunity(
        title: title,
        description: desc,
        postedByName: _postedByName,
        postedByPhoto: _postedByPhoto,
        orgRole: _orgRole,
        rolesWanted: _rolesWanted.toList(),
        city: city,
        region: region,
        postalCode: postal,
        budget: budget,
        startAt: startAt,
        eventId: widget.eventId,
        eventName: widget.eventName,
      );
      ok = id != null;
    } else {
      ok = await OpportunityService.updateOpportunity(
        widget.existing!.id,
        title: title,
        description: desc,
        rolesWanted: _rolesWanted.toList(),
        city: city,
        region: region,
        postalCode: postal,
        budget: budget,
        startAt: startAt,
        clearStartAt: startAt == null,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppToast.show(widget.existing == null
          ? 'Opportunity posted'
          : 'Opportunity updated');
      Navigator.pop(context, true);
    } else {
      AppToast.show('Could not save. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const whiteStyle = TextStyle(color: Colors.white, fontSize: 15);
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
          widget.existing == null ? 'Post opportunity' : 'Edit opportunity',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_orgRoles.length > 1) ...[
              _sectionLabel('Posting as'),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _orgRoles.map((r) {
                    final sel = _orgRole == r;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _applyPosterRole(r, updateName: true),
                        child: Container(
                          alignment: Alignment.center,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: sel
                                ? _accent
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel ? _accent : Colors.white24),
                          ),
                          child: Text(roleDisplayLabel(r),
                              style: TextStyle(
                                  color: sel ? Colors.black : Colors.white,
                                  fontSize: 13,
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _titleController,
              style: whiteStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Title (e.g. DJ for Saturday night)',
                  Icons.campaign_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add a title' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descController,
              style: whiteStyle,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Describe what you need', Icons.notes),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Add a short description'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openAiAssist,
                icon: const Icon(Icons.auto_awesome, size: 16, color: _accent),
                label: const Text('Write with AI',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            _chipGroup(
              'Who are you looking for?',
              individualRoles,
              _rolesWanted,
              labeller: roleDisplayLabel,
            ),
            _sectionLabel('Location'),
            TextFormField(
              controller: _cityController,
              style: whiteStyle,
              decoration: _dec('City', Icons.location_city),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _regionController,
                    style: whiteStyle,
                    decoration: _dec('Region', Icons.map_outlined),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _postalController,
                    style: whiteStyle,
                    keyboardType: TextInputType.text,
                    decoration: _dec('Postal code', Icons.markunread_mailbox_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sectionLabel('Budget & date'),
            TextFormField(
              controller: _budgetController,
              style: whiteStyle,
              keyboardType: TextInputType.number,
              decoration: _dec('Budget (optional)', Icons.attach_money),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: _accent.withOpacity(0.7), size: 22),
                    const SizedBox(width: 12),
                    Text(
                      _startDate == null
                          ? 'Date (optional)'
                          : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                      style: TextStyle(
                        color: _startDate == null
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white,
                        fontSize: 15,
                      ),
                    ),
                    const Spacer(),
                    if (_startDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _startDate = null),
                        child: const Icon(Icons.clear,
                            color: Colors.white54, size: 20),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        widget.existing == null
                            ? 'Post opportunity'
                            : 'Save changes',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _chipGroup(
    String title,
    List<String> options,
    Set<String> selected, {
    String Function(String)? labeller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600)),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final sel = selected.contains(o);
            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() {
                if (sel) {
                  selected.remove(o);
                } else {
                  selected.add(o);
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _accent : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _accent : Colors.white24),
                ),
                child: Text(labeller == null ? o : labeller(o),
                    style: TextStyle(
                        color: sel ? Colors.black : Colors.white,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: _accent.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accent.withOpacity(0.5), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }
}
