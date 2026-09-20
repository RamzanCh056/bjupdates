import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/musician_career_models.dart';
import '../../models/musician_document_models.dart';
import '../../services/musician_career_service.dart';
import '../../services/musician_document_service.dart';
import '../../utils/color.dart';

/// Musician-facing documents — a read-only list grouped by category, with
/// open/download per file. Mirrors the admin `documents` collection.
class MusicianDocumentsScreen extends StatefulWidget {
  const MusicianDocumentsScreen({super.key});

  @override
  State<MusicianDocumentsScreen> createState() =>
      _MusicianDocumentsScreenState();
}

class _MusicianDocumentsScreenState extends State<MusicianDocumentsScreen> {
  Musician? _musician;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        title: const Text('Documents',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: purpleAccent))
          : _musician == null
              ? _needsProfile()
              : StreamBuilder<List<MusicianDocument>>(
                  stream:
                      MusicianDocumentService.watchMyDocuments(_musician!.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child:
                              CircularProgressIndicator(color: purpleAccent));
                    }
                    final docs = snap.data ?? const <MusicianDocument>[];
                    if (docs.isEmpty) return _empty();
                    return _grouped(docs);
                  },
                ),
    );
  }

  Widget _needsProfile() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Register as a musician first to see your documents.',
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
              Icon(Icons.folder_open_outlined,
                  color: Colors.white.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text('No documents yet',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Contracts, setlists and other files shared with you will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
            ],
          ),
        ),
      );

  Widget _grouped(List<MusicianDocument> docs) {
    // Preserve newest-first order within each category group.
    final groups = <String, List<MusicianDocument>>{};
    for (final d in docs) {
      final key = d.category.isEmpty ? 'other' : d.category;
      groups.putIfAbsent(key, () => []).add(d);
    }
    final categories = groups.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 8, left: 2),
              child: Text(_titleCase(cat).toUpperCase(),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ),
            ...groups[cat]!.map(_docCard),
          ],
        );
      },
    );
  }

  Widget _docCard(MusicianDocument d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: d.url.isEmpty ? null : () => _openUrl(d.url),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: indigoColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_iconFor(d.extension),
                      color: purpleAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name.isEmpty ? 'Untitled' : d.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (d.extension.isNotEmpty) d.extension.toUpperCase(),
                          if (d.uploadedAt != null) _date(d.uploadedAt!),
                        ].join('  ·  '),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(d.url.isEmpty ? Icons.block : Icons.open_in_new,
                    size: 18, color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this document.')),
      );
    }
  }

  IconData _iconFor(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
      case 'csv':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image;
      case 'mp3':
      case 'wav':
      case 'm4a':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
        return Icons.movie;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _date(int ms) =>
      DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(ms));

  String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
