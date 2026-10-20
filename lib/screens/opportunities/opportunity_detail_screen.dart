import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/opportunity_models.dart';
import '../../services/opportunity_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../utils/role_utils.dart';
import 'create_opportunity_screen.dart';

/// Detail view for one opportunity.
///
/// Owner  → applicants list + accept/decline + edit/close/reopen/delete.
/// Others → details + Apply (with message) / applied status / withdraw.
class OpportunityDetailScreen extends StatefulWidget {
  final Opportunity opportunity;

  const OpportunityDetailScreen({super.key, required this.opportunity});

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  String? _myName;
  String? _myPhoto;
  String? _myRole;
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _uid != null && _uid == widget.opportunity.postedByUid;

  @override
  void initState() {
    super.initState();
    if (!_isOwner) _loadMe();
  }

  Future<void> _loadMe() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final roles = parseRolesFromUserData(data);
      final role = roles.firstWhere(
        (r) => r != RoleKeys.listener,
        orElse: () => roles.isNotEmpty ? roles.first : '',
      );
      final pro = (data['proProfile'] as Map<String, dynamic>?) ?? const {};
      final stage = (pro['stageName'] ?? '').toString().trim();
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      final name = stage.isNotEmpty
          ? stage
          : [first, last].where((s) => s.isNotEmpty).join(' ');
      if (!mounted) return;
      setState(() {
        _myName = name;
        _myPhoto = data['profileImage']?.toString();
        _myRole = role.isEmpty ? null : role;
      });
    } catch (_) {}
  }

  // --- applicant actions ----------------------------------------------------

  Future<void> _apply() async {
    final controller = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: darkBackgroundPrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apply to this opportunity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add a short message (optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Send application',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (send != true) return;
    setState(() => _busy = true);
    final ok = await OpportunityService.apply(
      oppId: widget.opportunity.id,
      applicantName: _myName ?? '',
      applicantPhoto: _myPhoto,
      applicantRole: _myRole,
      message: controller.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(ok ? 'Application sent' : 'Could not apply. Try again.',
        isError: !ok);
  }

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    final ok = await OpportunityService.withdraw(widget.opportunity.id);
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(ok ? 'Application withdrawn' : 'Could not withdraw',
        isError: !ok);
  }

  // --- owner actions --------------------------------------------------------

  Future<void> _setApplicantStatus(
      OpportunityApplication a, ApplicationStatus status) async {
    final ok = await OpportunityService.setApplicationStatus(
        widget.opportunity.id, a.applicantUid, status);
    if (!mounted) return;
    AppToast.show(ok ? '${a.applicantName}: ${status.label}' : 'Update failed',
        isError: !ok);
  }

  Future<void> _setStatus(OpportunityStatus status) async {
    final ok = await OpportunityService.setStatus(widget.opportunity.id, status);
    if (!mounted) return;
    AppToast.show(ok ? 'Marked ${status.label.toLowerCase()}' : 'Update failed',
        isError: !ok);
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOpportunityScreen(existing: widget.opportunity),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkBackgroundPrimary,
        title: const Text('Delete opportunity?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This removes the post and its applications. This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await OpportunityService.deleteOpportunity(widget.opportunity.id);
    if (!mounted) return;
    if (ok) {
      AppToast.show('Opportunity deleted');
      Navigator.pop(context);
    } else {
      AppToast.show('Could not delete', isError: true);
    }
  }

  // --- UI -------------------------------------------------------------------

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
        title: const Text(
          'Opportunity',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              iconColor: Colors.white,
              color: const Color(0xFF2A2A33),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _edit();
                    break;
                  case 'open':
                    _setStatus(OpportunityStatus.open);
                    break;
                  case 'filled':
                    _setStatus(OpportunityStatus.filled);
                    break;
                  case 'closed':
                    _setStatus(OpportunityStatus.closed);
                    break;
                  case 'delete':
                    _confirmDelete();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'open', child: Text('Mark open')),
                PopupMenuItem(value: 'filled', child: Text('Mark filled')),
                PopupMenuItem(value: 'closed', child: Text('Close')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: StreamBuilder<Opportunity?>(
        stream: OpportunityService.watchOne(widget.opportunity.id),
        initialData: widget.opportunity,
        builder: (context, snap) {
          final opp = snap.data ?? widget.opportunity;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _header(opp),
              const SizedBox(height: 16),
              if (opp.description.trim().isNotEmpty) ...[
                _body(opp.description),
                const SizedBox(height: 16),
              ],
              _metaCard(opp),
              const SizedBox(height: 20),
              if (_isOwner)
                _ownerApplicants(opp)
              else
                _applicantActions(opp),
            ],
          );
        },
      ),
    );
  }

  Widget _statusPill(OpportunityStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _header(Opportunity opp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                opp.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _statusPill(opp.status),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white24,
              backgroundImage: (opp.postedByPhoto ?? '').isNotEmpty
                  ? NetworkImage(opp.postedByPhoto!)
                  : null,
              child: (opp.postedByPhoto ?? '').isEmpty
                  ? const Icon(Icons.business, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                opp.postedByName.isEmpty ? 'Organizer' : opp.postedByName,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
        if (opp.rolesWanted.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opp.rolesWanted
                .map((r) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _accent.withOpacity(0.4)),
                      ),
                      child: Text(roleDisplayLabel(r),
                          style: const TextStyle(
                              color: _accent,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _body(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 14.5, height: 1.4)),
    );
  }

  Widget _metaCard(Opportunity opp) {
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _accent.withOpacity(0.8), size: 18),
            const SizedBox(width: 10),
            Text('$label: ',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13.5)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13.5)),
            ),
          ],
        ),
      ));
    }

    add(Icons.event_note, 'For event', opp.eventName ?? '');
    add(Icons.place, 'Location', opp.locationLine);
    if (opp.budget != null) {
      add(Icons.attach_money, 'Budget', opp.budget!.toString());
    }
    final d = opp.startDate;
    if (d != null) add(Icons.event, 'Date', '${d.day}/${d.month}/${d.year}');
    add(Icons.people_outline, 'Applicants', opp.applicantCount.toString());

    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: rows),
    );
  }

  // --- applicant (non-owner) view ------------------------------------------

  Widget _applicantActions(Opportunity opp) {
    return StreamBuilder<OpportunityApplication?>(
      stream: OpportunityService.watchMyApplication(opp.id),
      builder: (context, snap) {
        final app = snap.data;
        final applied = app != null && app.status != ApplicationStatus.withdrawn;

        if (!opp.status.isOpen && !applied) {
          return _infoBanner(
              'This opportunity is ${opp.status.label.toLowerCase()}.');
        }

        if (applied) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoBanner('Your application: ${app.status.label}'),
              const SizedBox(height: 12),
              if (app.status == ApplicationStatus.pending)
                OutlinedButton(
                  onPressed: _busy ? null : _withdraw,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Withdraw application',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        }

        return SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _apply,
            icon: const Icon(Icons.send, color: Colors.black, size: 18),
            label: const Text('Apply',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _infoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.3)),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 14)),
    );
  }

  // --- owner view -----------------------------------------------------------

  Widget _ownerApplicants(Opportunity opp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Applicants',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<OpportunityApplication>>(
          stream: OpportunityService.watchApplicants(opp.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(color: _accent)),
              );
            }
            final apps = snap.data ?? const [];
            if (apps.isEmpty) {
              return _infoBanner('No applications yet.');
            }
            return Column(
              children: apps.map(_applicantTile).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _applicantTile(OpportunityApplication a) {
    Color sc;
    switch (a.status) {
      case ApplicationStatus.accepted:
        sc = Colors.green;
        break;
      case ApplicationStatus.declined:
        sc = Colors.redAccent;
        break;
      default:
        sc = Colors.white54;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                backgroundImage: (a.applicantPhoto ?? '').isNotEmpty
                    ? NetworkImage(a.applicantPhoto!)
                    : null,
                child: (a.applicantPhoto ?? '').isEmpty
                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.applicantName.isEmpty ? 'Applicant' : a.applicantName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700),
                    ),
                    if ((a.applicantRole ?? '').isNotEmpty)
                      Text(roleDisplayLabel(a.applicantRole!),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12.5)),
                  ],
                ),
              ),
              Text(a.status.label,
                  style: TextStyle(
                      color: sc,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          if (a.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(a.message,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13.5, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: a.status == ApplicationStatus.accepted
                      ? null
                      : () => _setApplicantStatus(a, ApplicationStatus.accepted),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Accept',
                      style: TextStyle(color: Colors.green)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: a.status == ApplicationStatus.declined
                      ? null
                      : () => _setApplicantStatus(a, ApplicationStatus.declined),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
