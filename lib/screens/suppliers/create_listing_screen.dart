import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/supplier_models.dart';
import '../../services/supplier_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../utils/pro_profile_utils.dart';
import '../../utils/role_utils.dart';

/// Create or edit a supplier marketplace listing. Supplier-role gated by the
/// marketplace entry (My listings / Post).
class CreateListingScreen extends StatefulWidget {
  final SupplierListing? existing;
  const CreateListingScreen({super.key, this.existing});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  final _region = TextEditingController();

  final _picker = ImagePicker();
  String _category = supplierCategories.first;
  final List<File> _newImages = [];
  List<String> _existingImages = [];
  bool _saving = false;

  String _supplierName = '';
  String? _supplierPhoto;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = e.title;
      _desc.text = e.description;
      _price.text = e.priceInfo ?? '';
      _city.text = e.city ?? '';
      _region.text = e.region ?? '';
      _category = supplierCategories.contains(e.category)
          ? e.category
          : supplierCategories.first;
      _existingImages = List.of(e.imageUrls);
      _supplierName = e.supplierName;
      _supplierPhoto = e.supplierPhoto;
    }
    _loadSupplier();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    _city.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _loadSupplier() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usersData')
          .doc(uid)
          .get();
      final data = doc.data() ?? const <String, dynamic>{};
      final pro = proProfileForRole(data, RoleKeys.supplier) ?? const {};
      final orgName = (pro['orgName'] ?? '').toString().trim();
      final first = (data['firstName'] ?? '').toString().trim();
      final last = (data['secondName'] ?? '').toString().trim();
      final fallback = [first, last].where((s) => s.isNotEmpty).join(' ');
      if (!mounted) return;
      setState(() {
        if (_supplierName.isEmpty) {
          _supplierName = orgName.isNotEmpty ? orgName : fallback;
        }
        _supplierPhoto ??= data['profileImage']?.toString();
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (x != null) setState(() => _newImages.add(File(x.path)));
    } catch (_) {
      AppToast.show('Could not pick image', isError: true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final uploaded = <String>[];
    for (final f in _newImages) {
      final url = await SupplierService.uploadImage(f);
      if (url != null) uploaded.add(url);
    }
    final images = [..._existingImages, ...uploaded];

    bool ok;
    if (widget.existing == null) {
      final id = await SupplierService.createListing(
        title: _title.text,
        category: _category,
        description: _desc.text,
        supplierName: _supplierName,
        supplierPhoto: _supplierPhoto,
        priceInfo: _price.text,
        city: _city.text,
        region: _region.text,
        imageUrls: images,
      );
      ok = id != null;
    } else {
      ok = await SupplierService.updateListing(
        widget.existing!.id,
        title: _title.text,
        category: _category,
        description: _desc.text,
        priceInfo: _price.text,
        city: _city.text,
        region: _region.text,
        imageUrls: images,
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      AppToast.show(
          widget.existing == null ? 'Listing published' : 'Listing updated');
      Navigator.pop(context, true);
    } else {
      AppToast.show('Could not save. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const whiteStyle = TextStyle(color: Colors.white, fontSize: 15);
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
        title: Text(
          widget.existing == null ? 'New listing' : 'Edit listing',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _title,
              style: whiteStyle,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Title (e.g. Stage lighting package)',
                  Icons.inventory_2_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Add a title' : null,
            ),
            const SizedBox(height: 18),
            _label('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supplierCategories.map((c) {
                final sel = c == _category;
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _accent : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: sel ? _accent : Colors.white24),
                    ),
                    child: Text(c,
                        style: TextStyle(
                            color: sel ? Colors.black : Colors.white,
                            fontSize: 13,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _desc,
              style: whiteStyle,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec('Describe your service / equipment', Icons.notes),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Add a short description'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _price,
              style: whiteStyle,
              decoration: _dec('Price info (optional, e.g. \$500/day)',
                  Icons.sell_outlined),
            ),
            const SizedBox(height: 18),
            _label('Photos'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ..._existingImages.asMap().entries.map(
                    (e) => _netThumb(e.key, e.value)),
                ..._newImages.asMap().entries
                    .map((e) => _fileThumb(e.key, e.value)),
                _addTile(),
              ],
            ),
            const SizedBox(height: 18),
            _label('Location'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _city,
              style: whiteStyle,
              decoration: _dec('City', Icons.location_city),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _region,
              style: whiteStyle,
              decoration: _dec('Region', Icons.map_outlined),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : Text(
                        widget.existing == null
                            ? 'Publish listing'
                            : 'Save changes',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700));

  Widget _fileThumb(int i, File f) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(f, width: 86, height: 86, fit: BoxFit.cover),
      ),
      _removeBtn(() => setState(() => _newImages.removeAt(i))),
    ]);
  }

  Widget _netThumb(int i, String url) {
    return Stack(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(url, width: 86, height: 86, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 86,
                height: 86,
                color: Colors.white10,
                child: const Icon(Icons.broken_image, color: Colors.white38))),
      ),
      _removeBtn(() => setState(() => _existingImages.removeAt(i))),
    ]);
  }

  Widget _removeBtn(VoidCallback onTap) => Positioned(
        top: 2,
        right: 2,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration:
                const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            padding: const EdgeInsets.all(3),
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ),
      );

  Widget _addTile() => GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Icon(Icons.add_a_photo_outlined,
              color: Colors.white54, size: 26),
        ),
      );

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: _accent.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _accent.withOpacity(0.5), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }
}
