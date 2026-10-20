import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/opportunity_models.dart';
import '../../models/schedule_models.dart';
import '../../services/schedule_service.dart';
import '../../utils/color.dart';
import '../opportunities/opportunity_detail_screen.dart';

/// Personal calendar / schedule — a month grid of the user's events, gigs and
/// opportunities, with a day agenda below. Self-rendered (no calendar package).
class PersonalCalendarScreen extends StatefulWidget {
  const PersonalCalendarScreen({super.key});

  @override
  State<PersonalCalendarScreen> createState() =>
      _PersonalCalendarScreenState();
}

class _PersonalCalendarScreenState extends State<PersonalCalendarScreen> {
  static const Color _accent = Color(0xFFBB86FC);
  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  List<ScheduleItem> _items = const [];
  final Map<DateTime, List<ScheduleItem>> _byDay = {};
  bool _loading = true;

  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await ScheduleService.loadMySchedule();
    if (!mounted) return;
    _byDay.clear();
    for (final it in items) {
      _byDay.putIfAbsent(it.day, () => []).add(it);
    }
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  List<ScheduleItem> _itemsOn(DateTime day) =>
      _byDay[DateTime(day.year, day.month, day.day)] ?? const [];

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  Future<void> _openItem(ScheduleItem it) async {
    if (it.kind == ScheduleKind.opportunity && it.refId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('opportunities')
          .doc(it.refId)
          .get();
      if (!mounted || !doc.exists) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OpportunityDetailScreen(opportunity: Opportunity.fromDoc(doc)),
        ),
      );
      return;
    }
    _showItemSheet(it);
  }

  void _showItemSheet(ScheduleItem it) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: darkBackgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _kindBadge(it.kind),
                const Spacer(),
                Text(
                  '${it.date.day} ${_months[it.date.month - 1]} ${it.date.year}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(it.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800)),
            if ((it.subtitle ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(it.subtitle!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
            const SizedBox(height: 14),
            if ((it.time ?? '').isNotEmpty)
              _sheetRow(Icons.access_time, it.time!),
            if ((it.location ?? '').isNotEmpty)
              _sheetRow(Icons.place, it.location!),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: _accent.withOpacity(0.8), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      );

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
          'My calendar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _accent,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            _monthHeader(),
            const SizedBox(height: 10),
            _weekdayRow(),
            const SizedBox(height: 6),
            _grid(),
            const SizedBox(height: 18),
            _agendaHeader(),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 30),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              )
            else
              ..._agenda(),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        Text(
          '${_months[_visibleMonth.month - 1]} ${_visibleMonth.year}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        _roundIcon(Icons.chevron_left, () => _changeMonth(-1)),
        const SizedBox(width: 8),
        _roundIcon(Icons.chevron_right, () => _changeMonth(1)),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  Widget _weekdayRow() {
    return Row(
      children: _weekdays
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _grid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final leading = first.weekday - 1; // Mon-first
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final totalCells = ((leading + daysInMonth) / 7).ceil() * 7;
    final today = DateTime.now();

    final rows = <Widget>[];
    for (var r = 0; r < totalCells ~/ 7; r++) {
      final cells = <Widget>[];
      for (var c = 0; c < 7; c++) {
        final idx = r * 7 + c;
        final dayNum = idx - leading + 1;
        if (dayNum < 1 || dayNum > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 46)));
          continue;
        }
        final day =
            DateTime(_visibleMonth.year, _visibleMonth.month, dayNum);
        final hasItems = _itemsOn(day).isNotEmpty;
        final selected = _sameDay(day, _selectedDay);
        final isToday = _sameDay(day, today);
        cells.add(Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 46,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: (isToday && !selected)
                    ? Border.all(color: _accent.withOpacity(0.6))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      color: selected ? Colors.black : Colors.white,
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasItems
                          ? (selected ? Colors.black : _accent)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
      }
      rows.add(Row(children: cells));
    }
    return Column(children: rows);
  }

  Widget _agendaHeader() {
    final sel = _selectedDay;
    return Row(
      children: [
        Text(
          '${sel.day} ${_months[sel.month - 1]}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _sameDay(sel, DateTime.now()) ? '· Today' : '',
          style: const TextStyle(color: _accent, fontSize: 13),
        ),
      ],
    );
  }

  List<Widget> _agenda() {
    final dayItems = _itemsOn(_selectedDay);
    if (dayItems.isEmpty) {
      final upcoming = _items
          .where((it) => it.date.isAfter(DateTime.now()))
          .take(5)
          .toList();
      return [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            'Nothing scheduled on this day.',
            style:
                TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text('Upcoming',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...upcoming.map(_agendaTile),
        ],
      ];
    }
    return dayItems.map(_agendaTile).toList();
  }

  Widget _agendaTile(ScheduleItem it) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openItem(it),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _kindColor(it.kind),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _kindBadge(it.kind),
                        ],
                      ),
                      if ((it.subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(it.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12.5)),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if ((it.time ?? '').isNotEmpty) ...[
                            const Icon(Icons.access_time,
                                color: Colors.white38, size: 13),
                            const SizedBox(width: 4),
                            Text(it.time!,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                            const SizedBox(width: 12),
                          ],
                          if ((it.location ?? '').isNotEmpty) ...[
                            const Icon(Icons.place,
                                color: Colors.white38, size: 13),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                it.location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _kindColor(ScheduleKind kind) {
    switch (kind) {
      case ScheduleKind.event:
        return _accent;
      case ScheduleKind.gig:
        return const Color(0xFF34d399);
      case ScheduleKind.opportunity:
        return const Color(0xFFfbbf24);
    }
  }

  Widget _kindBadge(ScheduleKind kind) {
    final c = _kindColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(kind.label,
          style: TextStyle(
              color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
