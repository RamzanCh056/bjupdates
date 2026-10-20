import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/color.dart';
import '../utils/pro_profile_utils.dart';
import '../utils/role_utils.dart';

/// Read-only display of a user's professional / organization profile(s).
///
/// A user can have one profile per professional role. This shows the profile
/// for [role] (or the first available), with a small chip row to switch
/// between roles when the user has more than one. Renders nothing if the user
/// has no professional profile.
class ProProfileView extends StatefulWidget {
  final String uid;

  /// Preferred role to show first (e.g. the viewer's active role on their own
  /// profile). Falls back to the first available profile.
  final String? role;

  const ProProfileView({super.key, required this.uid, this.role});

  @override
  State<ProProfileView> createState() => _ProProfileViewState();
}

class _ProProfileViewState extends State<ProProfileView> {
  Map<String, Map<String, dynamic>> _profiles = const {};
  String? _selected;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(widget.uid)
          .get();
      final data = snap.data();
      _profiles = readProProfiles(data);
      _selected = pickProfileRole(data, preferred: widget.role);
    } catch (_) {
      _profiles = const {};
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _profiles.isEmpty || _selected == null) {
      return const SizedBox.shrink();
    }
    final pro = _profiles[_selected] ?? const {};
    if (pro.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_profiles.length > 1) _roleSwitcher(),
        _card(pro),
      ],
    );
  }

  Widget _roleSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _profiles.keys.map((r) {
            final sel = r == _selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selected = r),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: sel
                        ? purpleAccent.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: sel
                            ? purpleAccent
                            : Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Text(roleDisplayLabel(r),
                      style: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> pro) {
    String g(String k) => (pro[k] ?? '').toString().trim();
    final isOrg = g('kind') == 'organization';
    final role = g('role');
    final title = isOrg ? g('orgName') : g('stageName');
    final location = [
      g('city'),
      g('region'),
      g('postalCode'),
    ].where((e) => e.isNotEmpty).join(' · ');
    final desc = g('description');

    final rows = <Widget>[];
    void info(IconData icon, String value, {VoidCallback? onTap}) {
      if (value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                Icon(icon, size: 15, color: Colors.white54),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: onTap != null ? purpleAccent : Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (location.isNotEmpty) info(Icons.place_outlined, location);
    if (isOrg) {
      info(Icons.category_outlined, g('orgType'));
      info(Icons.groups_outlined, g('staffNeeded'));
    } else {
      info(Icons.star_outline, g('skills'));
    }
    info(Icons.phone_outlined, g('phone'));
    final site = g('website');
    if (site.isNotEmpty) info(Icons.language, site, onTap: () => _open(site));
    info(Icons.camera_alt_outlined, g('instagram'));
    info(Icons.facebook_outlined, g('facebook'));

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (role.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: purpleAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    roleDisplayLabel(role),
                    style: TextStyle(
                      color: purpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (title.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
          ...rows,
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    var u = url;
    if (!u.startsWith('http')) u = 'https://$u';
    final uri = Uri.tryParse(u);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
