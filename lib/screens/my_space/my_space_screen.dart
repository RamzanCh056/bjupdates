import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/opportunity_models.dart';
import '../../services/my_space_service.dart';
import '../../utils/color.dart';
import '../calendar/personal_calendar_screen.dart';
import '../directory/directory_screen.dart';
import '../opportunities/opportunity_board_screen.dart';
import '../opportunities/opportunity_detail_screen.dart';

/// "My Space" — a personal tracking hub that aggregates the user's events,
/// opportunities, applications and gigs, and surfaces what needs attention.
class MySpaceScreen extends StatefulWidget {
  const MySpaceScreen({super.key});

  @override
  State<MySpaceScreen> createState() => _MySpaceScreenState();
}

class _MySpaceScreenState extends State<MySpaceScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  MySpaceSummary _summary = const MySpaceSummary();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await MySpaceService.loadSummary();
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  Future<void> _openOpportunity(String id) async {
    if (id.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('opportunities')
        .doc(id)
        .get();
    if (!mounted || !doc.exists) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OpportunityDetailScreen(opportunity: Opportunity.fromDoc(doc)),
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
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
        title: const Text(
          'My space',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : RefreshIndicator(
              color: _accent,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _tilesGrid(),
                  const SizedBox(height: 22),
                  _attentionSection(),
                  const SizedBox(height: 22),
                  _quickLinks(),
                ],
              ),
            ),
    );
  }

  Widget _tilesGrid() {
    final s = _summary;
    final tiles = <Widget>[
      _tile(Icons.event, 'Events', '${s.events}', 'created', _accent),
      _tile(Icons.campaign_outlined, 'Opportunities', '${s.opportunities}',
          '${s.opportunitiesOpen} open', const Color(0xFFfbbf24)),
      _tile(Icons.send, 'Applications', '${s.applications}',
          '${s.applicationsAccepted} accepted · ${s.applicationsPending} pending',
          const Color(0xFF38bdf8)),
      _tile(Icons.work_outline, 'Gigs', '${s.gigs}',
          '${s.gigsUpcoming} upcoming', const Color(0xFF34d399)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: tiles,
    );
  }

  Widget _tile(IconData icon, String label, String value, String sub,
      Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _attentionSection() {
    final items = _summary.attention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Needs attention',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text("You're all caught up.",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 14)),
          )
        else
          ...items.map(_attentionCard),
      ],
    );
  }

  Widget _attentionCard(AttentionItem a) {
    final isReview = a.kind == AttentionKind.reviewApplicants;
    final color = isReview ? const Color(0xFFfbbf24) : const Color(0xFF34d399);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isReview) {
              _openOpportunity(a.refId);
            } else {
              _push(const OpportunityBoardScreen());
            }
          },
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                Icon(isReview ? Icons.how_to_reg : Icons.celebration,
                    color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700)),
                      if (a.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(a.subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickLinks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick links',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _linkRow(Icons.calendar_month_rounded, 'My calendar',
            () => _push(const PersonalCalendarScreen())),
        _linkRow(Icons.campaign_outlined, 'Gigs & opportunities',
            () => _push(const OpportunityBoardScreen())),
        _linkRow(Icons.groups_rounded, 'Directory',
            () => _push(const DirectoryScreen())),
      ],
    );
  }

  Widget _linkRow(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                Icon(icon, color: _accent, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
