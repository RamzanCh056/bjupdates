import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/opportunity_models.dart';
import '../../services/opportunity_service.dart';
import '../../utils/color.dart';
import '../../utils/role_utils.dart';
import 'create_opportunity_screen.dart';
import 'opportunity_detail_screen.dart';

/// Public "Gigs & opportunities" board.
///
/// Browse (everyone) · My applications (everyone) · My posts (org accounts).
class OpportunityBoardScreen extends StatefulWidget {
  const OpportunityBoardScreen({super.key});

  @override
  State<OpportunityBoardScreen> createState() => _OpportunityBoardScreenState();
}

class _OpportunityBoardScreenState extends State<OpportunityBoardScreen>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFBB86FC);

  List<String> _roles = const [];
  bool _loadingRoles = true;
  TabController? _tab;

  // Browse filters.
  String _roleFilter = '';
  final _cityController = TextEditingController();
  String _cityFilter = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _hasOrg => rolesHaveOrganization(_roles);

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _tab?.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loadingRoles = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      _roles = parseRolesFromUserData(doc.data());
    } catch (_) {
      _roles = const [];
    }
    final tabCount = _hasOrg ? 3 : 2;
    _tab = TabController(length: tabCount, vsync: this);
    if (mounted) setState(() => _loadingRoles = false);
  }

  Future<void> _openCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateOpportunityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Browse'),
      const Tab(text: 'My applications'),
      if (_hasOrg) const Tab(text: 'My posts'),
    ];

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Gigs & opportunities',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: _loadingRoles || _tab == null
            ? null
            : TabBar(
                controller: _tab,
                isScrollable: true,
                indicatorColor: _accent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: tabs,
              ),
      ),
      floatingActionButton: _hasOrg
          ? FloatingActionButton.extended(
              backgroundColor: _accent,
              onPressed: _openCreate,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('Post',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w700)),
            )
          : null,
      body: _loadingRoles || _tab == null
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : TabBarView(
              controller: _tab,
              children: [
                _browseTab(),
                _myApplicationsTab(),
                if (_hasOrg) _myPostsTab(),
              ],
            ),
    );
  }

  // --- Browse ---------------------------------------------------------------

  Widget _browseTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: TextField(
            controller: _cityController,
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => _cityFilter = v.trim()),
            decoration: InputDecoration(
              hintText: 'Filter by city',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.white54, size: 20),
              suffixIcon: _cityFilter.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear,
                          color: Colors.white54, size: 18),
                      onPressed: () {
                        _cityController.clear();
                        setState(() => _cityFilter = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _roleChip('', 'All'),
              ...individualRoles.map((r) => _roleChip(r, roleDisplayLabel(r))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Opportunity>>(
            stream: OpportunityService.watchBoard(
              roleWanted: _roleFilter,
              city: _cityFilter,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _accent));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return _empty('No open opportunities match your filters yet.');
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: list.length,
                itemBuilder: (_, i) => _OpportunityCard(
                  opp: list[i],
                  onTap: () => _openDetail(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _roleChip(String role, String label) {
    final sel = _roleFilter == role;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _roleFilter = role),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: sel ? _accent : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? _accent : Colors.white24),
          ),
          child: Text(label,
              style: TextStyle(
                  color: sel ? Colors.black : Colors.white,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }

  // --- My applications ------------------------------------------------------

  Widget _myApplicationsTab() {
    return StreamBuilder<List<OpportunityApplication>>(
      stream: OpportunityService.watchMyApplications(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _accent));
        }
        final apps = snap.data ?? const [];
        if (apps.isEmpty) {
          return _empty("You haven't applied to anything yet.");
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: apps.length,
          itemBuilder: (_, i) => _ApplicationCard(
            app: apps[i],
            onTap: () => _openDetailById(apps[i].opportunityId),
          ),
        );
      },
    );
  }

  // --- My posts -------------------------------------------------------------

  Widget _myPostsTab() {
    final uid = _uid ?? '';
    return StreamBuilder<List<Opportunity>>(
      stream: OpportunityService.watchMyPosts(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _accent));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return _empty('You have not posted any opportunities yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: list.length,
          itemBuilder: (_, i) => _OpportunityCard(
            opp: list[i],
            showStatus: true,
            onTap: () => _openDetail(list[i]),
          ),
        );
      },
    );
  }

  // --- helpers --------------------------------------------------------------

  void _openDetail(Opportunity opp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpportunityDetailScreen(opportunity: opp),
      ),
    );
  }

  Future<void> _openDetailById(String id) async {
    if (id.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('opportunities')
        .doc(id)
        .get();
    if (!mounted || !doc.exists) return;
    _openDetail(Opportunity.fromDoc(doc));
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_outline,
                color: Colors.white.withOpacity(0.3), size: 54),
            const SizedBox(height: 14),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 14.5)),
          ],
        ),
      ),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final Opportunity opp;
  final VoidCallback onTap;
  final bool showStatus;

  const _OpportunityCard({
    required this.opp,
    required this.onTap,
    this.showStatus = false,
  });

  static const Color _accent = Color(0xFFBB86FC);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        opp.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (showStatus) ...[
                      const SizedBox(width: 8),
                      _miniStatus(opp.status),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  opp.postedByName.isEmpty ? 'Organizer' : opp.postedByName,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                if (opp.rolesWanted.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: opp.rolesWanted
                        .take(4)
                        .map((r) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(roleDisplayLabel(r),
                                  style: const TextStyle(
                                      color: _accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (opp.locationLine.isNotEmpty) ...[
                      const Icon(Icons.place,
                          color: Colors.white38, size: 15),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          opp.locationLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Icon(Icons.people_outline,
                        color: Colors.white38, size: 15),
                    const SizedBox(width: 4),
                    Text('${opp.applicantCount}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12.5)),
                    if (opp.budget != null) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.attach_money,
                          color: Colors.white38, size: 15),
                      Text(opp.budget!.toString(),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12.5)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStatus(OpportunityStatus status) {
    Color c;
    switch (status) {
      case OpportunityStatus.open:
        c = Colors.green;
        break;
      case OpportunityStatus.filled:
        c = Colors.orange;
        break;
      case OpportunityStatus.closed:
        c = Colors.redAccent;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: c, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final OpportunityApplication app;
  final VoidCallback onTap;

  const _ApplicationCard({required this.app, required this.onTap});

  static const Color _accent = Color(0xFFBB86FC);

  @override
  Widget build(BuildContext context) {
    Color sc;
    switch (app.status) {
      case ApplicationStatus.accepted:
        sc = Colors.green;
        break;
      case ApplicationStatus.declined:
        sc = Colors.redAccent;
        break;
      default:
        sc = Colors.white54;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send, color: _accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (app.message.trim().isNotEmpty)
                        Text(
                          app.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        )
                      else
                        const Text('Application sent',
                            style: TextStyle(
                                color: Colors.white, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(app.status.label,
                      style: TextStyle(
                          color: sc,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
