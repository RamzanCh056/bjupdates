import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/verification_models.dart';
import '../../services/verification_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../../widgets/app_badges.dart';

/// Lets a user request the admin-approved "Verified" badge by uploading proof.
class GetVerifiedScreen extends StatefulWidget {
  const GetVerifiedScreen({super.key});

  @override
  State<GetVerifiedScreen> createState() => _GetVerifiedScreenState();
}

class _GetVerifiedScreenState extends State<GetVerifiedScreen> {
  static const Color _accent = Color(0xFFBB86FC);

  final _picker = ImagePicker();
  final _noteController = TextEditingController();
  final List<File> _proofs = [];
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    try {
      final XFile? x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (x != null) setState(() => _proofs.add(File(x.path)));
    } catch (_) {
      AppToast.show('Could not pick image', isError: true);
    }
  }

  Future<void> _submit() async {
    if (_proofs.isEmpty) {
      AppToast.show('Add at least one proof image', isError: true);
      return;
    }
    setState(() => _submitting = true);
    final urls = <String>[];
    for (final f in _proofs) {
      final url = await VerificationService.uploadProof(f);
      if (url != null) urls.add(url);
    }
    if (urls.isEmpty) {
      if (mounted) setState(() => _submitting = false);
      AppToast.show('Upload failed. Try again.', isError: true);
      return;
    }
    final ok = await VerificationService.submitRequest(
      proofUrls: urls,
      note: _noteController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      _proofs.clear();
      AppToast.show('Request submitted for review');
    } else {
      AppToast.show('Could not submit. Try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Get verified',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
      ),
      body: StreamBuilder<VerificationRequest?>(
        stream: VerificationService.watchMyRequest(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _accent));
          }
          final req = snap.data;
          final status = req?.status ?? VerifStatus.none;

          switch (status) {
            case VerifStatus.approved:
              return _statusState(
                icon: null,
                title: "You're verified",
                body: 'Your identity has been approved. The verified badge now '
                    'shows on your profile.',
                tone: VerifiedBadge.color,
                showBadge: true,
              );
            case VerifStatus.pending:
              return _statusState(
                icon: Icons.hourglass_top_rounded,
                title: 'Under review',
                body: 'We received your request. An admin will review your '
                    'proof and approve or get back to you.',
                tone: const Color(0xFFF6A623),
              );
            case VerifStatus.rejected:
              return _form(
                rejected: true,
                reason: req?.rejectReason,
              );
            case VerifStatus.none:
              return _form();
          }
        },
      ),
    );
  }

  Widget _statusState({
    required IconData? icon,
    required String title,
    required String body,
    required Color tone,
    bool showBadge = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBadge)
              const VerifiedBadge(size: 64)
            else
              Icon(icon, color: tone, size: 60),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _form({bool rejected = false, String? reason}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        Row(
          children: [
            const VerifiedBadge(size: 30),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Get the verified badge',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Verification confirms your real identity or organization. Upload a '
          'clear proof (ID, business document, or official page) — an admin '
          'reviews it before approving.',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13.5,
              height: 1.5),
        ),
        if (rejected) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Previous request was rejected',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5)),
                if ((reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(reason!.trim(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
                const SizedBox(height: 4),
                const Text('You can submit again with clearer proof.',
                    style: TextStyle(color: Colors.white54, fontSize: 12.5)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        const Text('Proof',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._proofs.asMap().entries.map((e) => _thumb(e.key, e.value)),
            _addTile(),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Note (optional)',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _noteController,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Anything that helps the reviewer',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Text('Submit for review',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _thumb(int index, File file) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: 86, height: 86, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => setState(() => _proofs.removeAt(index)),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _addTile() {
    return GestureDetector(
      onTap: _pick,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add_a_photo_outlined,
            color: Colors.white54, size: 26),
      ),
    );
  }
}
