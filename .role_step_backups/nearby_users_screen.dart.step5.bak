import 'dart:ui';

import 'package:beatjerky/screens/messages_screen.dart';
import 'package:beatjerky/screens/view_user_profile_screen.dart';
import 'package:beatjerky/services/chat_service.dart';
import 'package:beatjerky/services/nearby_users_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

// Design tokens
const _accent = Color(0xFFa855f7);
const _accentLight = Color(0xFFc084fc);
const _accentDeep = Color(0xFF7c3aed);
const _pageBg = Color(0xFF0d1117);
const _surface = Color(0xFF121829);
const _radiusOptions = [1.0, 5.0, 10.0, 25.0];

const _avatarGradients = <List<Color>>[
  [Color(0xFF7c3aed), Color(0xFFa855f7)],
  [Color(0xFFdb2777), Color(0xFFf472b6)],
  [Color(0xFF2563eb), Color(0xFF38bdf8)],
  [Color(0xFF059669), Color(0xFF34d399)],
  [Color(0xFFd97706), Color(0xFFfbbf24)],
  [Color(0xFF4f46e5), Color(0xFF818cf8)],
];

LinearGradient _gradientForSeed(String seed) {
  final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
  final pair = _avatarGradients[hash % _avatarGradients.length];
  return LinearGradient(
    colors: pair,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

enum _NearbyTab { nearby, all }

class NearbyUsersScreen extends StatefulWidget {
  const NearbyUsersScreen({super.key});

  @override
  State<NearbyUsersScreen> createState() => _NearbyUsersScreenState();
}

class _NearbyUsersScreenState extends State<NearbyUsersScreen>
    with TickerProviderStateMixin {
  _NearbyTab _tab = _NearbyTab.nearby;
  double _radiusKm = 10;
  NearbyGenderFilter _gender = NearbyGenderFilter.all;
  NearbyUsersResult? _result;
  bool _loading = true;
  int _listGeneration = 0;

  late TabController _tabController;
  late AnimationController _radiusRevealController;
  late Animation<double> _radiusReveal;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: const Duration(milliseconds: 250),
    );
    _tabController.addListener(_onTabChanged);

    _radiusRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
    _radiusReveal = CurvedAnimation(
      parent: _radiusRevealController,
      curve: Curves.easeOutCubic,
    );

    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _radiusRevealController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final next = _tabController.index == 0 ? _NearbyTab.nearby : _NearbyTab.all;
    if (next == _tab) return;
    setState(() => _tab = next);
    if (next == _NearbyTab.nearby) {
      _radiusRevealController.forward();
    } else {
      _radiusRevealController.reverse();
    }
    _load();
  }

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _listGeneration++;
    });

    final NearbyUsersResult result;
    if (_tab == _NearbyTab.all) {
      result = await NearbyUsersService.fetchAll(gender: _gender);
    } else {
      result = await NearbyUsersService.fetchNearby(
        radiusKm: _radiusKm,
        refreshLocation: refresh,
        gender: _gender,
      );
    }

    if (mounted) {
      setState(() {
        _result = result;
        _loading = false;
      });
    }
  }

  Future<void> _enableLocation() async {
    final permission = await NearbyUsersService.requestPermission();
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    await _load(refresh: true);
  }

  Future<void> _messageUser(NearbyUser user) async {
    try {
      final chatId = await ChatService.openOrCreateChat(
        peerUid: user.uid,
        peerName: user.displayName,
        peerPhoto: user.photoURL,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerUid: user.uid,
            peerName: user.displayName,
            peerImage: user.photoURL,
            chatId: chatId,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open chat: $e'),
            backgroundColor: _surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m away';
    return '${km.toStringAsFixed(1)} km away';
  }

  String _formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'Active recently';
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Active yesterday';
    return 'Active ${diff.inDays}d ago';
  }

  double? _nextRadiusUp() {
    for (final r in _radiusOptions) {
      if (r > _radiusKm) return r;
    }
    return null;
  }

  String get _resultsLabel {
    if (_loading) return 'Searching…';
    final count = _result?.users.length ?? 0;
    if (_tab == _NearbyTab.nearby) {
      return count == 0 ? 'No one within ${_radiusKm.toInt()} km' : '$count nearby';
    }
    return count == 0 ? 'No users found' : '$count people';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                Expanded(
                  child: RefreshIndicator(
                    color: _accent,
                    backgroundColor: _surface,
                    onRefresh: () => _load(refresh: true),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your exact address is never shown — only approximate distance.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _SegmentedTabBar(controller: _tabController),
                                const SizedBox(height: 14),
                                AnimatedBuilder(
                                  animation: _radiusReveal,
                                  builder: (context, _) => _FiltersPanel(
                                    radiusReveal: _radiusReveal.value,
                                    radiusKm: _radiusKm,
                                    gender: _gender,
                                    onRadiusSelected: (km) {
                                      if (_radiusKm == km) return;
                                      setState(() => _radiusKm = km);
                                      _load(refresh: true);
                                    },
                                    onGenderSelected: (g) {
                                      if (_gender == g) return;
                                      setState(() => _gender = g);
                                      _load();
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ResultsBadge(label: _resultsLabel, loading: _loading),
                              ],
                            ),
                          ),
                        ),
                        ..._buildListSlivers(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
          decoration: BoxDecoration(
            color: _pageBg.withValues(alpha: 0.75),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Discover',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Artists & fans around you',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withValues(alpha: 0.2),
                      _accentLight.withValues(alpha: 0.08),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withValues(alpha: 0.25)),
                ),
                child: Icon(Icons.radar_rounded,
                    size: 18, color: _accentLight.withValues(alpha: 0.95)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildListSlivers() {
    if (_loading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, __) => const _SkeletonUserCard(),
              childCount: 5,
            ),
          ),
        ),
      ];
    }

    final result = _result;
    if (result == null) {
      return [SliverFillRemaining(hasScrollBody: false, child: _ErrorEmptyBody(message: 'Something went wrong. Pull to refresh.'))];
    }

    if (_tab == _NearbyTab.nearby && result.permissionDenied) {
      return [SliverFillRemaining(hasScrollBody: false, child: _LocationPromptBody(onEnable: _enableLocation))];
    }

    if (result.errorMessage != null) {
      return [SliverFillRemaining(hasScrollBody: false, child: _ErrorEmptyBody(message: result.errorMessage!))];
    }

    if (result.users.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _tab == _NearbyTab.nearby
              ? _NearbyEmptyBody(
                  nextRadius: _nextRadiusUp(),
                  currentRadius: _radiusKm,
                  onExpandRadius: (km) {
                    setState(() => _radiusKm = km);
                    _load(refresh: true);
                  },
                )
              : const _AllEmptyBody(),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final user = result.users[index];
              return _AnimatedUserCard(
                key: ValueKey('${user.uid}_$_listGeneration'),
                index: index,
                animate: !_reduceMotion,
                child: _UserCard(
                  user: user,
                  showDistance: _tab == _NearbyTab.nearby,
                  distanceLabel: _formatDistance(user.distanceKm),
                  activityLabel: _formatLastActive(user.lastActive),
                  onTap: () => openUserProfile(context, user.uid),
                  onMessage: () => _messageUser(user),
                ),
              );
            },
            childCount: result.users.length,
          ),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Background & chrome
// ---------------------------------------------------------------------------

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: _pageBg),
        Positioned(
          top: -80,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accent.withValues(alpha: 0.18),
                  _accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _accentLight.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultsBadge extends StatelessWidget {
  final String label;
  final bool loading;

  const _ResultsBadge({required this.label, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 11,
              height: 11,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _accent.withValues(alpha: 0.85),
              ),
            )
          else
            Icon(Icons.bolt_rounded, size: 14, color: _accentLight.withValues(alpha: 0.8)),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabBar extends StatelessWidget {
  final TabController controller;

  const _SegmentedTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, _) {
        final slide = controller.animation!.value.clamp(0.0, 1.0);
        const outerPad = 4.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final innerW = constraints.maxWidth - outerPad * 2;
                final segW = innerW / 2;

                return Stack(
                  children: [
                    Positioned(
                      left: outerPad + segW * slide,
                      top: outerPad,
                      bottom: outerPad,
                      width: segW,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_accentDeep, _accent, _accentLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(outerPad),
                      child: Row(
                        children: [
                          _SegmentTab(
                            label: 'Nearby',
                            icon: Icons.near_me_rounded,
                            progress: (1 - slide).clamp(0.0, 1.0),
                            onTap: () => controller.animateTo(0),
                          ),
                          _SegmentTab(
                            label: 'All',
                            icon: Icons.groups_rounded,
                            progress: slide.clamp(0.0, 1.0),
                            onTap: () => controller.animateTo(1),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final double progress;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.icon,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = progress > 0.55;
    final color = Color.lerp(
      Colors.white.withValues(alpha: 0.42),
      Colors.white,
      progress,
    );

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    letterSpacing: -0.1,
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

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

class _FiltersPanel extends StatelessWidget {
  final double radiusReveal;
  final double radiusKm;
  final NearbyGenderFilter gender;
  final ValueChanged<double> onRadiusSelected;
  final ValueChanged<NearbyGenderFilter> onGenderSelected;

  const _FiltersPanel({
    required this.radiusReveal,
    required this.radiusKm,
    required this.gender,
    required this.onRadiusSelected,
    required this.onGenderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: radiusReveal.clamp(0, 1),
            child: Opacity(
              opacity: radiusReveal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterLabel(icon: Icons.radar_rounded, text: 'Distance'),
                  const SizedBox(height: 10),
                  _FilterChipRow(
                    children: _radiusOptions.map((km) {
                      final label = km == km.roundToDouble() ? '${km.toInt()} km' : '$km km';
                      return _FilterChip(
                        label: label,
                        selected: radiusKm == km,
                        onTap: () => onRadiusSelected(km),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ),
        _FilterLabel(icon: Icons.tune_rounded, text: 'Filter'),
        const SizedBox(height: 10),
        _FilterChipRow(
          children: [
            _FilterChip(
              label: 'All',
              selected: gender == NearbyGenderFilter.all,
              onTap: () => onGenderSelected(NearbyGenderFilter.all),
            ),
            _FilterChip(
              label: 'Male',
              selected: gender == NearbyGenderFilter.male,
              onTap: () => onGenderSelected(NearbyGenderFilter.male),
            ),
            _FilterChip(
              label: 'Female',
              selected: gender == NearbyGenderFilter.female,
              onTap: () => onGenderSelected(NearbyGenderFilter.female),
            ),
            _FilterChip(
              label: 'Other',
              selected: gender == NearbyGenderFilter.other,
              onTap: () => onGenderSelected(NearbyGenderFilter.other),
            ),
          ],
        ),
      ],
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FilterLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.35)),
        const SizedBox(width: 5),
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  final List<Widget> children;

  const _FilterChipRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1, end: 0.93).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTapDown: (_) {
        if (!reduceMotion) _press.forward();
      },
      onTapUp: (_) {
        if (!reduceMotion) _press.reverse();
        widget.onTap();
      },
      onTapCancel: () {
        if (!reduceMotion) _press.reverse();
      },
      child: ScaleTransition(
        scale: reduceMotion ? const AlwaysStoppedAnimation(1) : _scale,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: widget.selected
                ? const LinearGradient(
                    colors: [_accentDeep, _accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.selected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.selected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.08),
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User card
// ---------------------------------------------------------------------------

class _UserCard extends StatefulWidget {
  final NearbyUser user;
  final bool showDistance;
  final String distanceLabel;
  final String activityLabel;
  final VoidCallback onTap;
  final VoidCallback onMessage;

  const _UserCard({
    required this.user,
    required this.showDistance,
    required this.distanceLabel,
    required this.activityLabel,
    required this.onTap,
    required this.onMessage,
  });

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final initial = widget.user.displayName.isNotEmpty
        ? widget.user.displayName[0].toUpperCase()
        : '?';
    final grad = _gradientForSeed(widget.user.uid);

    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.98 : 1,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: widget.user.isOnline
                ? LinearGradient(
                    colors: [
                      _accent.withValues(alpha: 0.35),
                      _accentLight.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            border: widget.user.isOnline
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(
                color: widget.user.isOnline
                    ? _accent.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            margin: widget.user.isOnline ? const EdgeInsets.all(1) : EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141b2d),
              borderRadius: BorderRadius.circular(widget.user.isOnline ? 21 : 22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _AvatarWithStatus(
                  photoURL: widget.user.photoURL,
                  initial: initial,
                  seed: widget.user.uid,
                  gradient: grad,
                  isOnline: widget.user.isOnline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.user.isOnline)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Color(0xFF4ade80),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            widget.showDistance
                                ? Icons.place_rounded
                                : Icons.access_time_rounded,
                            size: 12,
                            color: widget.showDistance
                                ? _accentLight.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              widget.showDistance
                                  ? widget.distanceLabel
                                  : widget.activityLabel,
                              style: TextStyle(
                                color: widget.showDistance
                                    ? _accentLight.withValues(alpha: 0.9)
                                    : Colors.white.withValues(alpha: 0.4),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.user.bio != null &&
                          widget.user.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          widget.user.bio!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.38),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MessageButton(onPressed: widget.onMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvatarWithStatus extends StatelessWidget {
  final String? photoURL;
  final String initial;
  final String seed;
  final LinearGradient gradient;
  final bool isOnline;

  const _AvatarWithStatus({
    required this.photoURL,
    required this.initial,
    required this.seed,
    required this.gradient,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoURL != null && photoURL!.isNotEmpty;

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isOnline
                  ? const LinearGradient(
                      colors: [_accent, _accentLight, Color(0xFF22C55E)],
                    )
                  : gradient,
            ),
            child: ClipOval(
              child: hasPhoto
                  ? CachedNetworkImage(
                      imageUrl: photoURL!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _InitialAvatar(
                        initial: initial,
                        gradient: gradient,
                        size: 56,
                      ),
                      errorWidget: (_, __, ___) => _InitialAvatar(
                        initial: initial,
                        gradient: gradient,
                        size: 56,
                      ),
                    )
                  : _InitialAvatar(initial: initial, gradient: gradient, size: 56),
            ),
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF141b2d), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String initial;
  final LinearGradient gradient;
  final double size;

  const _InitialAvatar({
    required this.initial,
    required this.gradient,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: gradient),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _MessageButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white24,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_accentDeep, _accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 16),
              SizedBox(width: 5),
              Text(
                'Hi',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedUserCard extends StatefulWidget {
  final int index;
  final bool animate;
  final Widget child;

  const _AnimatedUserCard({
    super.key,
    required this.index,
    required this.animate,
    required this.child,
  });

  @override
  State<_AnimatedUserCard> createState() => _AnimatedUserCardState();
}

class _AnimatedUserCardState extends State<_AnimatedUserCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    if (widget.animate) {
      Future<void>.delayed(Duration(milliseconds: widget.index * 45), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    final opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _SkeletonUserCard extends StatelessWidget {
  const _SkeletonUserCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF141b2d),
      highlightColor: Colors.white.withValues(alpha: 0.05),
      period: const Duration(milliseconds: 1300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141b2d),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Colors.white10,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 16,
                    width: 130,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 12,
                    width: 90,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error states
// ---------------------------------------------------------------------------

class _EmptyStateShell extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyStateShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 28),
            action!,
          ],
        ],
      ),
    );
  }
}

class _EmptyIconRing extends StatelessWidget {
  final IconData icon;

  const _EmptyIconRing({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _accent.withValues(alpha: 0.22),
            _accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: _accent.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.15),
            blurRadius: 32,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: _accentLight.withValues(alpha: 0.9)),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_accentDeep, _accent, _accentLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyEmptyBody extends StatelessWidget {
  final double? nextRadius;
  final double currentRadius;
  final ValueChanged<double> onExpandRadius;

  const _NearbyEmptyBody({
    required this.nextRadius,
    required this.currentRadius,
    required this.onExpandRadius,
  });

  @override
  Widget build(BuildContext context) {
    return _EmptyStateShell(
      icon: const _EmptyIconRing(icon: Icons.location_searching_rounded),
      title: 'No one nearby yet',
      subtitle: 'There\'s nobody within ${currentRadius.toInt()} km right now.\nTry widening your search area.',
      action: nextRadius != null
          ? _GradientButton(
              label: 'Expand to ${nextRadius!.toInt()} km',
              icon: Icons.open_in_full_rounded,
              onTap: () => onExpandRadius(nextRadius!),
            )
          : null,
    );
  }
}

class _AllEmptyBody extends StatelessWidget {
  const _AllEmptyBody();

  @override
  Widget build(BuildContext context) {
    return const _EmptyStateShell(
      icon: _EmptyIconRing(icon: Icons.people_outline_rounded),
      title: 'No one to show yet',
      subtitle: 'Be the first to complete your profile\nand show up here for others to discover.',
    );
  }
}

class _LocationPromptBody extends StatelessWidget {
  final VoidCallback onEnable;

  const _LocationPromptBody({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    return _EmptyStateShell(
      icon: const _EmptyIconRing(icon: Icons.location_off_rounded),
      title: 'Location needed',
      subtitle: 'Enable location to discover artists and fans near you.\nYour exact address is never shared.',
      action: _GradientButton(
        label: 'Enable Location',
        icon: Icons.my_location_rounded,
        onTap: onEnable,
      ),
    );
  }
}

class _ErrorEmptyBody extends StatelessWidget {
  final String message;

  const _ErrorEmptyBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return _EmptyStateShell(
      icon: const _EmptyIconRing(icon: Icons.cloud_off_rounded),
      title: 'Couldn\'t load users',
      subtitle: message,
    );
  }
}

// ---------------------------------------------------------------------------
// Home entry
// ---------------------------------------------------------------------------

class NearbyUsersHomeSection extends StatelessWidget {
  const NearbyUsersHomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NearbyUsersScreen()),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.12),
                    _surface.withValues(alpha: 0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_accentDeep, _accent],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.near_me_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nearby Artists & Fans',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'See who\'s around — your address stays private',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.white.withValues(alpha: 0.35)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
