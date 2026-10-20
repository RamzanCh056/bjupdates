import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/drive_service.dart';
import '../utils/app_toast.dart';

/// A bottom action bar for financial documents (invoices, royalty statements).
///
/// Offers two on-demand actions:
///  - **Share / Print** the generated PDF via the OS share sheet.
///  - **Save to Drive** – uploads the PDF to the user's Google Drive
///    (BeatJerky folder) using the narrow `drive.file` scope.
class DocActionsBar extends StatefulWidget {
  /// Builds the PDF bytes on demand (so generation only happens when tapped).
  final Future<Uint8List> Function() buildPdf;

  /// File name (without needing the .pdf extension).
  final String fileName;

  const DocActionsBar({
    super.key,
    required this.buildPdf,
    required this.fileName,
  });

  @override
  State<DocActionsBar> createState() => _DocActionsBarState();
}

class _DocActionsBarState extends State<DocActionsBar> {
  bool _sharing = false;
  bool _saving = false;

  Future<void> _share() async {
    if (_sharing || _saving) return;
    setState(() => _sharing = true);
    try {
      final bytes = await widget.buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: '${widget.fileName}.pdf');
    } catch (e) {
      AppToast.show('Could not prepare PDF', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _saveToDrive() async {
    if (_sharing || _saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await widget.buildPdf();
      final res = await DriveService.uploadPdf(
        bytes: bytes,
        fileName: widget.fileName,
      );
      if (!mounted) return;
      if (res.cancelled) {
        AppToast.show('Google sign-in cancelled');
      } else {
        AppToast.show(res.message, isError: !res.ok);
      }
    } catch (e) {
      AppToast.show('Could not save to Drive', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sharing ? null : _share,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _sharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share, size: 18),
                label: const Text('Share / Print'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveToDrive,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_to_drive, size: 18),
                label: const Text('Save to Drive'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
