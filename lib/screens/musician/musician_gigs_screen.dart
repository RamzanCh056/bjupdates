import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/musician_career_models.dart';
import '../../models/musician_gig_models.dart';
import '../../services/musician_career_service.dart';
import '../../services/musician_gig_service.dart';
import '../../utils/color.dart';

/// Musician-facing gigs, shown as an agenda grouped by date bucket
/// (Today / This week / Later / Past). Offered gigs can be accepted or declined.
class MusicianGigsScreen extends StatefulWidget {
  const MusicianGigsScreen({super.key});

  @override
  State<MusicianGigsScreen> createState() => _MusicianGigsScreenState();
}

class _MusicianGigsScreenState extends State<MusicianGigsScreen> {
  Musician? _musician;
  bool _loading = true;
  String? _busyGigId;

  @override
  void initState() {
    super.initState();
    _loadMusician();
  }

  Future<void> _loadMusician() async {
    final m = await MusicianCareerService.getMyMusician();
    if (!mounted) return;
    setState(() {
      _musician = m;
      _loading = false;
    });
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
        title: const Text('My gigs',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purpleAccent))
          : _musician == null
              ? _needsProfile()
              : StreamBuilder<List<Gig>>(
                  stream: MusicianGigService.watchMyGigs(_musician!.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(color: purpleAccent));
                    }
                    final gigs = (snap.data ?? const <Gig>[])
                        .where((g) => g.status != GigStatus.draft)
                        .toList();
                    if (gigs.isEmpty) return _empty();
                    return _agenda(gigs);
                  },
                ),
    );
  }

  Widget _needsProfile() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Register as a musician first to see gigs assigned to you.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          ),
        ),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_note_outlined,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('No gigs yet',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Gigs the BeatJerky team books for you will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            ],
          ),
        ),
      );

  // --- agenda grouping ------------------------------------------------------

  Widget _agenda(List<Gig> gigs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final buckets = <String, List<Gig>>{
      'Today': [],
      'This week': [],
      'Later': [],
      'Past': [],
    };
    for (final g in gigs) {
      final d = g.startDate;
      if (d == null) {
        buckets['Later']!.add(g);
        continue;
      }
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(today)) {
        buckets['Past']!.add(g);
      } else if (day == today) {
        buckets['Today']!.add(g);
      } else if (day.isBefore(weekEnd)) {
        buckets['This week']!.add(g);
      } else {
        buckets['Later']!.add(g);
      }
    }

    final sections = buckets.entries.where((e) => e.value.isNotEmpty).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 8, left: 2),
              child: Text(section.key.toUpperCase(),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            ...section.value.map(_gigCard),
          ],
        );
      },
    );
  }

  Widget _gigCard(Gig g) {
    final busy = _busyGigId == g.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(g.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              _statusPill(g.status),
            ],
          ),
          if (g.startDate != null) ...[
            const SizedBox(height: 8),
            _iconLine(Icons.schedule, _formatWhen(g.startDate!)),
          ],
          if ((g.venue ?? '').isNotEmpty)
            _iconLine(Icons.place_outlined,
                [g.venue, g.address].where((s) => (s ?? '').isNotEmpty).join(' · ')),
          if (g.role != null)
            _iconLine(Icons.music_note, g.role!.label),
          if (g.paymentAmount != null)
            _iconLine(Icons.payments_outlined,
                '${g.currency ?? ''} ${g.paymentAmount!.toStringAsFixed(0)}'.trim()),
          if ((g.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(g.notes!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    height: 1.35)),
          ],
          if (g.status.awaitingResponse) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _respond(g, accept: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: busy ? null : buttonGradient,
                      color: busy ? Colors.white.withValues(alpha: 0.1) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextButton(
                      onPressed: busy ? null : () => _respond(g, accept: true),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Accept',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(Gig g, {required bool accept}) async {
    setState(() => _busyGigId = g.id);
    try {
      if (accept) {
        await MusicianGigService.accept(g.id);
      } else {
        await MusicianGigService.decline(g.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(accept ? 'Gig accepted.' : 'Gig declined.'),
            backgroundColor: darkBackgroundTertiary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the gig. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyGigId = null);
    }
  }

  Widget _iconLine(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.55)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            ),
          ],
        ),
      );

  String _formatWhen(DateTime d) {
    final date = DateFormat('EEE, MMM d').format(d);
    final time = DateFormat('h:mm a').format(d);
    return '$date · $time';
  }

  Widget _statusPill(GigStatus status) {
    Color c;
    switch (status) {
      case GigStatus.accepted:
      case GigStatus.confirmed:
        c = greenColor;
        break;
      case GigStatus.offered:
        c = eventsColor;
        break;
      case GigStatus.declined:
      case GigStatus.cancelled:
        c = redColor;
        break;
      case GigStatus.completed:
        c = purpleAccent;
        break;
      case GigStatus.draft:
        c = greyColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(status.label,
          style:
              TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
