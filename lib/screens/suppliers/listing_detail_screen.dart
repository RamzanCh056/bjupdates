import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/supplier_models.dart';
import '../../services/supplier_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import 'create_listing_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  final SupplierListing listing;
  const ListingDetailScreen({super.key, required this.listing});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  String? _myName;
  String? _myPhoto;
  bool _busy = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  bool get _isOwner => _uid != null && _uid == widget.listing.supplierUid;

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
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _myName = [first, last].where((s) => s.isNotEmpty).join(' ');
        _myPhoto = data['profileImage']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _request() async {
    final controller = TextEditingController();
    final send = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: darkBackgroundPrimary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
            const Text('Request this service',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'What do you need, and when? (optional)',
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
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Send request',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
    if (send != true) return;
    setState(() => _busy = true);
    final ok = await SupplierService.request(
      listingId: widget.listing.id,
      requesterName: _myName ?? '',
      requesterPhoto: _myPhoto,
      message: controller.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(ok ? 'Request sent' : 'Could not send. Try again.',
        isError: !ok);
  }

  Future<void> _withdraw() async {
    setState(() => _busy = true);
    final ok = await SupplierService.withdraw(widget.listing.id);
    if (!mounted) return;
    setState(() => _busy = false);
    AppToast.show(ok ? 'Request withdrawn' : 'Could not withdraw',
        isError: !ok);
  }

  Future<void> _setReq(SupplierRequest r, RequestStatus s) async {
    final ok =
        await SupplierService.setRequestStatus(widget.listing.id, r.requesterUid, s);
    if (!mounted) return;
    AppToast.show(ok ? '${r.requesterName}: ${s.label}' : 'Update failed',
        isError: !ok);
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkBackgroundPrimary,
        title: const Text('Delete listing?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This removes the listing and its requests.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await SupplierService.deleteListing(widget.listing.id);
    if (!mounted) return;
    if (ok) {
      AppToast.show('Listing deleted');
      Navigator.pop(context);
    } else {
      AppToast.show('Could not delete', isError: true);
    }
  }

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
        title: const Text('Listing',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              iconColor: Colors.white,
              color: const Color(0xFF2A2A33),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CreateListingScreen(
                                existing: widget.listing)));
                    break;
                  case 'active':
                    SupplierService.setStatus(
                        widget.listing.id, ListingStatus.active);
                    break;
                  case 'pause':
                    SupplierService.setStatus(
                        widget.listing.id, ListingStatus.paused);
                    break;
                  case 'delete':
                    _confirmDelete();
                    break;
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'active', child: Text('Mark active')),
                PopupMenuItem(value: 'pause', child: Text('Pause')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
        ],
      ),
      body: StreamBuilder<SupplierListing?>(
        stream: SupplierService.watchOne(widget.listing.id),
        initialData: widget.listing,
        builder: (context, snap) {
          final l = snap.data ?? widget.listing;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              if (l.imageUrls.isNotEmpty) _gallery(l.imageUrls),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(l.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (l.status == ListingStatus.paused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Paused',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(l.category,
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.supplierName.isEmpty ? 'Supplier' : l.supplierName,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (l.description.trim().isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(l.description,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14.5, height: 1.4)),
                ),
                const SizedBox(height: 14),
              ],
              _metaCard(l),
              const SizedBox(height: 20),
              if (_isOwner) _ownerRequests(l) else _requesterActions(l),
            ],
          );
        },
      ),
    );
  }

  Widget _gallery(List<String> urls) {
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(urls[i],
              width: 260,
              height: 190,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 260,
                  color: Colors.white10,
                  child: const Icon(Icons.broken_image,
                      color: Colors.white38))),
        ),
      ),
    );
  }

  Widget _metaCard(SupplierListing l) {
    final rows = <Widget>[];
    void add(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, color: _accent.withOpacity(0.8), size: 18),
          const SizedBox(width: 10),
          Text('$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 13.5)),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13.5)),
          ),
        ]),
      ));
    }

    add(Icons.sell_outlined, 'Price', l.priceInfo ?? '');
    add(Icons.place, 'Location', l.locationLine);
    add(Icons.people_outline, 'Requests', l.requestCount.toString());
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

  Widget _requesterActions(SupplierListing l) {
    return StreamBuilder<SupplierRequest?>(
      stream: SupplierService.watchMyRequest(l.id),
      builder: (context, snap) {
        final req = snap.data;
        final requested =
            req != null && req.status != RequestStatus.withdrawn;
        if (!l.status.isActive && !requested) {
          return _banner('This listing is paused.');
        }
        if (requested) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _banner('Your request: ${req.status.label}'),
              const SizedBox(height: 12),
              if (req.status == RequestStatus.pending)
                OutlinedButton(
                  onPressed: _busy ? null : _withdraw,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Withdraw request',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          );
        }
        return SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : _request,
            icon: const Icon(Icons.send, color: Colors.black, size: 18),
            label: const Text('Request',
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        );
      },
    );
  }

  Widget _banner(String text) => Container(
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

  Widget _ownerRequests(SupplierListing l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Requests',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        StreamBuilder<List<SupplierRequest>>(
          stream: SupplierService.watchRequests(l.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: _accent)),
              );
            }
            final reqs = snap.data ?? const [];
            if (reqs.isEmpty) return _banner('No requests yet.');
            return Column(children: reqs.map(_reqTile).toList());
          },
        ),
      ],
    );
  }

  Widget _reqTile(SupplierRequest r) {
    Color sc;
    switch (r.status) {
      case RequestStatus.accepted:
        sc = Colors.green;
        break;
      case RequestStatus.declined:
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
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: (r.requesterPhoto ?? '').isNotEmpty
                  ? NetworkImage(r.requesterPhoto!)
                  : null,
              child: (r.requesterPhoto ?? '').isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                  r.requesterName.isEmpty ? 'Requester' : r.requesterName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
            Text(r.status.label,
                style: TextStyle(
                    color: sc, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          if (r.message.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.message,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13.5, height: 1.35)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: r.status == RequestStatus.accepted
                    ? null
                    : () => _setReq(r, RequestStatus.accepted),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child:
                    const Text('Accept', style: TextStyle(color: Colors.green)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: r.status == RequestStatus.declined
                    ? null
                    : () => _setReq(r, RequestStatus.declined),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Decline',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
