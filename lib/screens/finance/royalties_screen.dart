import 'package:flutter/material.dart';

import '../../models/invoice_models.dart' show DocStatus, DocStatusX;
import '../../models/royalty_models.dart';
import '../../services/royalty_service.dart';
import '../../utils/color.dart';
import 'create_royalty_screen.dart';
import 'royalty_detail_screen.dart';

class RoyaltiesScreen extends StatelessWidget {
  const RoyaltiesScreen({super.key});

  static const Color _accent = Color(0xFFBB86FC);

  Color _tone(DocStatus s) {
    switch (s) {
      case DocStatus.paid:
        return Colors.green;
      case DocStatus.sent:
        return const Color(0xFF38bdf8);
      case DocStatus.draft:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: darkBackgroundPrimary,
        appBar: AppBar(
          backgroundColor: darkAppBarBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Royalty statements',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          bottom: const TabBar(
            indicatorColor: _accent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Issued'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _accent,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateRoyaltyScreen()),
          ),
          icon: const Icon(Icons.add, color: Colors.black),
          label: const Text(
            'New',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
        body: TabBarView(
          children: [
            _list(context, RoyaltyService.watchIssued(), issued: true),
            _list(context, RoyaltyService.watchReceived(), issued: false),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    Stream<List<RoyaltyStatement>> stream, {
    required bool issued,
  }) {
    return StreamBuilder<List<RoyaltyStatement>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                issued
                    ? 'No statements issued yet.'
                    : 'No statements received yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14.5,
                ),
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final st = list[i];
            final c = _tone(st.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RoyaltyDetailScreen(statement: st),
                    ),
                  ),
                  child: Ink(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issued
                                    ? (st.artistName.isEmpty
                                          ? 'Artist'
                                          : st.artistName)
                                    : (st.labelName.isEmpty
                                          ? 'Label'
                                          : st.labelName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${st.period.isEmpty ? 'Statement' : st.period} · ${st.tracks.length} track${st.tracks.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${st.net.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: c.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                st.status.label,
                                style: TextStyle(
                                  color: c,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
