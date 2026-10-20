import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/supplier_models.dart';
import '../../services/supplier_service.dart';
import '../../utils/color.dart';
import '../../utils/role_utils.dart';
import 'create_listing_screen.dart';
import 'listing_detail_screen.dart';

/// Suppliers & equipment marketplace.
/// Browse (everyone) · My requests (everyone) · My listings (suppliers).
class SupplierMarketplaceScreen extends StatefulWidget {
  const SupplierMarketplaceScreen({super.key});

  @override
  State<SupplierMarketplaceScreen> createState() =>
      _SupplierMarketplaceScreenState();
}

class _SupplierMarketplaceScreenState extends State<SupplierMarketplaceScreen>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFBB86FC);

  List<String> _roles = const [];
  bool _loadingRoles = true;
  TabController? _tab;

  String _category = '';
  final _cityController = TextEditingController();
  String _cityFilter = '';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isSupplier => _roles.contains(RoleKeys.supplier);

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
    _tab = TabController(length: _isSupplier ? 3 : 2, vsync: this);
    if (mounted) setState(() => _loadingRoles = false);
  }

  void _openCreate() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const CreateListingScreen()));
  }

  void _openDetail(SupplierListing l) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Browse'),
      const Tab(text: 'My requests'),
      if (_isSupplier) const Tab(text: 'My listings'),
    ];
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Suppliers & equipment',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
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
      floatingActionButton: _isSupplier
          ? FloatingActionButton.extended(
              backgroundColor: _accent,
              onPressed: _openCreate,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('List service',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.w700)),
            )
          : null,
      body: _loadingRoles || _tab == null
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : TabBarView(
              controller: _tab,
              children: [
                _browse(),
                _myRequests(),
                if (_isSupplier) _myListings(),
              ],
            ),
    );
  }

  // --- browse ---------------------------------------------------------------

  Widget _browse() {
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
                      }),
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
              _catChip('', 'All'),
              ...supplierCategories.map((c) => _catChip(c, c)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<SupplierListing>>(
            stream: SupplierService.watchMarketplace(
                category: _category, city: _cityFilter),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _accent));
              }
              final list = snap.data ?? const [];
              if (list.isEmpty) {
                return _empty('No listings match your filters yet.');
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    _ListingCard(listing: list[i], onTap: () => _openDetail(list[i])),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catChip(String cat, String label) {
    final sel = _category == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _category = cat),
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

  // --- my requests ----------------------------------------------------------

  Widget _myRequests() {
    return StreamBuilder<List<SupplierRequest>>(
      stream: SupplierService.watchMyRequests(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final reqs = snap.data ?? const [];
        if (reqs.isEmpty) {
          return _empty("You haven't requested anything yet.");
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: reqs.length,
          itemBuilder: (_, i) => _RequestCard(
            req: reqs[i],
            onTap: () => _openDetailById(reqs[i].listingId),
          ),
        );
      },
    );
  }

  // --- my listings ----------------------------------------------------------

  Widget _myListings() {
    final uid = _uid ?? '';
    return StreamBuilder<List<SupplierListing>>(
      stream: SupplierService.watchMyListings(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return _empty('You have no listings yet.');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          itemCount: list.length,
          itemBuilder: (_, i) => _ListingCard(
            listing: list[i],
            showStatus: true,
            onTap: () => _openDetail(list[i]),
          ),
        );
      },
    );
  }

  Future<void> _openDetailById(String id) async {
    if (id.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('supplierListings')
        .doc(id)
        .get();
    if (!mounted || !doc.exists) return;
    _openDetail(SupplierListing.fromDoc(doc));
  }

  Widget _empty(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
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

class _ListingCard extends StatelessWidget {
  final SupplierListing listing;
  final VoidCallback onTap;
  final bool showStatus;
  const _ListingCard(
      {required this.listing, required this.onTap, this.showStatus = false});

  static const Color _accent = Color(0xFFBB86FC);

  @override
  Widget build(BuildContext context) {
    final img = listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (img != null)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.network(img,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            height: 140,
                            color: Colors.white10,
                            child: const Icon(Icons.broken_image,
                                color: Colors.white38))),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(listing.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          if (showStatus &&
                              listing.status == ListingStatus.paused) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('Paused',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(listing.category,
                              style: const TextStyle(
                                  color: _accent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            listing.supplierName.isEmpty
                                ? 'Supplier'
                                : listing.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12.5),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        if ((listing.priceInfo ?? '').trim().isNotEmpty) ...[
                          const Icon(Icons.sell_outlined,
                              color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Text(listing.priceInfo!,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12.5)),
                          const SizedBox(width: 12),
                        ],
                        if (listing.locationLine.isNotEmpty) ...[
                          const Icon(Icons.place,
                              color: Colors.white38, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(listing.locationLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12.5)),
                          ),
                        ],
                      ]),
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
}

class _RequestCard extends StatelessWidget {
  final SupplierRequest req;
  final VoidCallback onTap;
  const _RequestCard({required this.req, required this.onTap});

  static const Color _accent = Color(0xFFBB86FC);

  @override
  Widget build(BuildContext context) {
    Color sc;
    switch (req.status) {
      case RequestStatus.accepted:
        sc = Colors.green;
        break;
      case RequestStatus.declined:
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
            child: Row(children: [
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
                child: Text(
                  req.message.trim().isEmpty ? 'Request sent' : req.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
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
                child: Text(req.status.label,
                    style: TextStyle(
                        color: sc,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
