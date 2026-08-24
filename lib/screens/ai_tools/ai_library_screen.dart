import 'package:beatjerky/model/generated_beat_model.dart';
import 'package:beatjerky/models/ai_library_item.dart';
import 'package:beatjerky/screens/ai_tools/ai_tools_theme.dart';
import 'package:beatjerky/services/ai_beat_generator_service.dart';
import 'package:beatjerky/services/ai_library_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class AiLibraryScreen extends StatefulWidget {
  const AiLibraryScreen({super.key});

  @override
  State<AiLibraryScreen> createState() => _AiLibraryScreenState();
}

class _AiLibraryScreenState extends State<AiLibraryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return AiToolsScreen(
      title: 'AI Library',
      children: [
        _FilterRow(
          value: _filter,
          onChanged: (v) => setState(() => _filter = v),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<AiLibraryItem>>(
          stream: AiLibraryService.watchLibrary(),
          builder: (context, librarySnap) {
            return StreamBuilder<List<GeneratedBeat>>(
              stream: AiLibraryService.watchBeats(),
              builder: (context, beatsSnap) {
                if (librarySnap.connectionState == ConnectionState.waiting &&
                    beatsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AiToolsTheme.purple),
                    ),
                  );
                }

                final items = librarySnap.data ?? const [];
                final beats = beatsSnap.data ?? const [];
                final filteredItems = _filterItems(items, beats);

                if (filteredItems.isEmpty) {
                  return const AiToolsEmptyState(
                    message:
                        'Nothing saved yet. Generate lyrics, beats, vocals, or scores and tap Save to Library.',
                  );
                }

                return Column(
                  children: filteredItems.map(_buildEntry).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  List<_LibraryEntry> _filterItems(
    List<AiLibraryItem> items,
    List<GeneratedBeat> beats,
  ) {
    final entries = <_LibraryEntry>[
      for (final beat in beats)
        _LibraryEntry.beat(beat),
      for (final item in items)
        _LibraryEntry.item(item),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_filter == 'all') return entries;
    if (_filter == 'audio') {
      return entries
          .where((e) => e.isBeat || (e.item?.hasAudio ?? false))
          .toList();
    }
    if (_filter == 'lyrics') {
      return entries.where((e) => e.item?.type == 'lyrics').toList();
    }
    if (_filter == 'scores') {
      return entries
          .where(
            (e) =>
                e.item?.type == 'viral_score' ||
                e.item?.type == 'mood_playlist' ||
                e.item?.type == 'stem',
          )
          .toList();
    }
    return entries;
  }

  Widget _buildEntry(_LibraryEntry entry) {
    if (entry.isBeat) {
      final beat = entry.beat!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _LibraryCard(
          title: beat.title,
          subtitle: 'Beat · ${beat.genres.join(', ')}',
          icon: Icons.music_note_rounded,
          colors: const [Color(0xFF7B2FF7), Color(0xFF9D4EDD)],
          createdAt: beat.createdAt ?? DateTime.now(),
          onPlay: beat.hasPlayableAudio
              ? () => AiBeatGeneratorService.playBeat(beat)
              : null,
        ),
      );
    }

    final item = entry.item!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _LibraryCard(
        title: item.title,
        subtitle: '${item.typeLabel} · ${item.sourceTool}',
        icon: _iconForType(item.type),
        colors: _colorsForType(item.type),
        createdAt: item.createdAt,
        onTap: () => _openItem(item),
        onDelete: () async {
          await AiLibraryService.deleteItem(item.id);
          if (mounted) AppToast.show('Removed from library.');
        },
      ),
    );
  }

  Future<void> _openItem(AiLibraryItem item) async {
    if (!item.hasText) {
      AppToast.show('No preview for this item.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AiToolsTheme.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AiToolsTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: SelectableText(
                        item.textContent!,
                        style: const TextStyle(
                          color: AiToolsTheme.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: item.textContent!),
                            );
                            AppToast.show('Copied.');
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Share.share(item.textContent!),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'lyrics':
        return Icons.edit_note_rounded;
      case 'viral_score':
        return Icons.insights_rounded;
      case 'vocal':
        return Icons.mic_rounded;
      case 'script_music':
        return Icons.movie_creation_outlined;
      case 'mood_playlist':
        return Icons.podcasts_rounded;
      case 'stem':
        return Icons.graphic_eq_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  List<Color> _colorsForType(String type) {
    switch (type) {
      case 'lyrics':
        return const [Color(0xFFF107A3), Color(0xFFC026D3)];
      case 'viral_score':
        return const [Color(0xFF22D3EE), Color(0xFF10B981)];
      case 'vocal':
        return const [Color(0xFF4CC9F0), Color(0xFF4361EE)];
      case 'script_music':
        return const [Color(0xFF22C55E), Color(0xFF14B8A6)];
      case 'mood_playlist':
        return const [Color(0xFFEC4899), Color(0xFF8B5CF6)];
      case 'stem':
        return const [Color(0xFF4CC9F0), Color(0xFF1E3A8A)];
      default:
        return const [Color(0xFF7B2FF7), Color(0xFF9D4EDD)];
    }
  }
}

class _LibraryEntry {
  final AiLibraryItem? item;
  final GeneratedBeat? beat;
  final DateTime createdAt;

  _LibraryEntry._({this.item, this.beat, required this.createdAt});

  factory _LibraryEntry.item(AiLibraryItem item) =>
      _LibraryEntry._(item: item, createdAt: item.createdAt);

  factory _LibraryEntry.beat(GeneratedBeat beat) => _LibraryEntry._(
        beat: beat,
        createdAt: beat.createdAt ?? DateTime.now(),
      );

  bool get isBeat => beat != null;
}

class _FilterRow extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FilterRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const filters = [
      ('all', 'All'),
      ('audio', 'Audio'),
      ('lyrics', 'Lyrics'),
      ('scores', 'Reports'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final selected = value == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected ? AiToolsTheme.primaryGradient : null,
                  color: selected ? null : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: selected ? Colors.white : AiToolsTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LibraryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final DateTime createdAt;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDelete;

  const _LibraryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.createdAt,
    this.onTap,
    this.onPlay,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy').format(createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AiToolsTheme.radiusMd),
        child: AiToolsGlassCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AiToolsTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$subtitle · $date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AiToolsTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (onPlay != null)
                IconButton(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
