import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../utils/app_toast.dart';
import '../utils/color.dart';
import '../utils/pro_profile_utils.dart';
import '../utils/role_utils.dart';

/// Role-aware professional / organization profile editor.
///
/// A user can have several professional roles, each with its OWN profile. This
/// screen shows a role selector; the fields load and save per selected role to
/// `usersData/{uid}.proProfiles.<role>` (deep-merged, so other roles' profiles
/// are untouched). Individual roles (artist, DJ, band, technician) and
/// organization roles (venue, agency, studio, label, supplier, organizer) see
/// different fields.
class EditProProfileScreen extends StatefulWidget {
  /// Optional role to open first; defaults to the first professional role.
  final String? initialRole;

  const EditProProfileScreen({super.key, this.initialRole});

  @override
  State<EditProProfileScreen> createState() => _EditProProfileScreenState();
}

class _EditProProfileScreenState extends State<EditProProfileScreen> {
  static const Color _muted = Color(0xFFB0B0B0);

  // Common
  final _city = TextEditingController();
  final _region = TextEditingController();
  final _postal = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  // Individual
  final _stageName = TextEditingController();
  final _skills = TextEditingController();
  // Organization
  final _orgName = TextEditingController();
  final _orgType = TextEditingController();
  final _staffNeeded = TextEditingController();
  final _description = TextEditingController();

  Map<String, dynamic> _data = const {};
  List<String> _roles = const [];
  String _role = RoleKeys.artist;
  bool get _isOrg => isOrganizationRole(_role);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _city, _region, _postal, _phone, _website, _instagram, _facebook,
      _stageName, _skills, _orgName, _orgType, _staffNeeded, _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      _data = snap.data() ?? {};

      // The user's professional roles (everything except listener).
      final all = parseRolesFromUserData(_data);
      _roles = all.where((r) => r != RoleKeys.listener).toList();

      // Switching into a role they don't hold yet: let them set up its
      // profile here first; the switch itself completes once they save.
      final want = widget.initialRole;
      if (want != null && !_roles.contains(want)) {
        _roles = [want, ..._roles];
      }

      if (_roles.isNotEmpty) {
        _role = (want != null && _roles.contains(want)) ? want : _roles.first;
        _fillFor(_role);
      }
    } catch (_) {
      // keep empty on error
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Load the controllers from the saved sub-profile for [role].
  void _fillFor(String role) {
    final pro = proProfileForRole(_data, role) ?? const {};
    String g(String k) => (pro[k] ?? '').toString();
    _city.text = g('city');
    _region.text = g('region');
    _postal.text = g('postalCode');
    _phone.text = g('phone');
    _website.text = g('website');
    _instagram.text = g('instagram');
    _facebook.text = g('facebook');
    _stageName.text = g('stageName');
    _skills.text = g('skills');
    _orgName.text = g('orgName');
    _orgType.text = g('orgType');
    _staffNeeded.text = g('staffNeeded');
    _description.text = g('description');
  }

  void _selectRole(String role) {
    if (role == _role) return;
    setState(() {
      _role = role;
      _fillFor(role);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);

    String t(TextEditingController c) => c.text.trim();
    final pro = <String, dynamic>{
      'kind': _isOrg ? 'organization' : 'individual',
      'role': _role,
      'city': t(_city),
      'region': t(_region),
      'postalCode': t(_postal),
      'phone': t(_phone),
      'website': t(_website),
      'instagram': t(_instagram),
      'facebook': t(_facebook),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (_isOrg) {
      pro.addAll({
        'orgName': t(_orgName),
        'orgType': t(_orgType),
        'staffNeeded': t(_staffNeeded),
        'description': t(_description),
      });
    } else {
      pro.addAll({
        'stageName': t(_stageName),
        'skills': t(_skills),
      });
    }

    try {
      // Deep-merge into proProfiles.<role> so other roles stay intact.
      await FirebaseFirestore.instance.collection('usersData').doc(uid).set({
        'proProfiles': {_role: pro},
      }, SetOptions(merge: true));
      // Keep the local copy in sync so switching roles here shows fresh data.
      final profiles = Map<String, dynamic>.from(
          (_data['proProfiles'] as Map?)?.cast<String, dynamic>() ?? {});
      profiles[_role] = pro;
      _data = {..._data, 'proProfiles': profiles};

      // Entered to set up a role the user doesn't hold yet: the profile now
      // exists, so complete the switch into that role.
      if (widget.initialRole == _role && mounted) {
        await context.read<UserStatusProvider>().switchRoleAndPersist(_role);
      }

      if (mounted) {
        AppToast.show('${roleDisplayLabel(_role)} profile saved.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) AppToast.show('Could not save: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkBackgroundPrimary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _roles.isEmpty ? 'Professional profile' : '${roleDisplayLabel(_role)} profile',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
              ? _noRoleState()
              : _form(),
    );
  }

  Widget _noRoleState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                color: Colors.white.withValues(alpha: 0.3), size: 54),
            const SizedBox(height: 14),
            const Text(
              'You don\'t have a professional role yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Switch to a professional role (DJ, band, venue, agency, etc.) from your profile, then set up its profile here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        if (_roles.length > 1) ...[
          _header('Editing profile for'),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _roles.map((r) {
                final sel = r == _role;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _selectRole(r),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: sel
                            ? purpleAccent
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sel ? purpleAccent : Colors.white24),
                      ),
                      child: Text(roleDisplayLabel(r),
                          style: TextStyle(
                              color: sel ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          _isOrg
              ? 'Tell people about your organization.'
              : 'Tell people about your work.',
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        if (_isOrg) ...[
          _header('Organization'),
          _field(_orgName, 'Organization name'),
          _field(_orgType, 'Organization type (e.g. nightclub, agency)'),
          _field(_staffNeeded, 'Artists / staff usually needed', maxLines: 2),
          _field(_description, 'Short description',
              maxLines: 3, maxLength: 300),
        ] else ...[
          _header('About you'),
          _field(_stageName, 'Stage name'),
          _field(_skills, 'Skills / instruments / services', maxLines: 2),
        ],
        const SizedBox(height: 10),
        _header('Location'),
        _field(_city, 'City'),
        _field(_region, 'Province / region'),
        _field(_postal, 'Postal code'),
        const SizedBox(height: 10),
        _header('Contact & links'),
        _field(_phone, 'Phone', keyboard: TextInputType.phone),
        _field(_website, 'Website'),
        _field(_instagram, 'Instagram'),
        _field(_facebook, 'Facebook'),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Saving…' : 'Save profile',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _field(TextEditingController c, String hint,
      {int maxLines = 1, int? maxLength, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _muted),
          counterStyle: const TextStyle(color: _muted),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: purpleAccent),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
