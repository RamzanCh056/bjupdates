import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/music_store/song_list_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../providers/music_store_provider/music_store_provider.dart';
import '../store/create_store_screen.dart';
import 'music_store_model.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({Key? key}) : super(key: key);
  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicStoreProvider>().fetchStores();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<MusicStoreProvider>().stores;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final myStores = stores.where((s) => s.userId == currentUserId).toList();
    final otherStores = stores.where((s) => s.userId != currentUserId).toList();

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final isTablet = size.width >= 600;
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet ? 0.8 : 0.75;
    final bottomGridPadding = 16.0 + mediaQuery.padding.bottom + 72.0;

    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Music Stores',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: darkAppBarBackground,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: appGradient,
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Own store'),
                Tab(text: 'All stores'),
              ],
            ),
          ),
        ),
      ),
      body: stores.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBB86FC).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      size: 64,
                      color: Color(0xFFBB86FC),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No Music Stores Yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first music store to get started',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildOwnStoresTab(
                  myStores,
                  currentUserId,
                  crossAxisCount,
                  childAspectRatio,
                  bottomGridPadding,
                ),
                _buildAllStoresTab(
                  otherStores,
                  currentUserId,
                  crossAxisCount,
                  childAspectRatio,
                  bottomGridPadding,
                ),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: appGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: recntsColor.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            if (!context.read<UserStatusProvider>().canManageVenueAndEvents) {
              AppToast.show(
                'Only Organizers and Venues can create venue/store profiles',
                isError: true,
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateStoreScreen(isMusicStore: true),
              ),
            );
          },
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildOwnStoresTab(
    List<MusicStoreModel> list,
    String? currentUserId,
    int crossAxisCount,
    double childAspectRatio,
    double bottomGridPadding,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFBB86FC).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.store_outlined,
                size: 64,
                color: Color(0xFFBB86FC),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No stores yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first music store to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return _buildStoresGrid(
      list,
      currentUserId,
      crossAxisCount,
      childAspectRatio,
      bottomGridPadding,
    );
  }

  Widget _buildAllStoresTab(
    List<MusicStoreModel> list,
    String? currentUserId,
    int crossAxisCount,
    double childAspectRatio,
    double bottomGridPadding,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.store_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No other stores',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Music stores from others will appear here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return _buildStoresGrid(
      list,
      currentUserId,
      crossAxisCount,
      childAspectRatio,
      bottomGridPadding,
    );
  }

  Widget _buildStoresGrid(
    List<MusicStoreModel> list,
    String? currentUserId,
    int crossAxisCount,
    double childAspectRatio,
    double bottomGridPadding,
  ) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomGridPadding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildStoreTile(list[i], currentUserId),
    );
  }

  Widget _buildStoreTile(MusicStoreModel store, String? currentUserId) {
    final isOwner = store.userId == currentUserId;
    return Stack(
      children: [
        StoreCard(store: store, currentUserId: currentUserId),
        if (isOwner)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              child: PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
                onSelected: (value) async {
                  if (!context
                      .read<UserStatusProvider>()
                      .canManageVenueAndEvents) {
                    AppToast.show(
                      'Only Organizers and Venues can manage venue/store profiles',
                      isError: true,
                    );
                    return;
                  }
                  if (value == 'edit') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CreateStoreScreen(isMusicStore: true, store: store),
                      ),
                    );
                  } else if (value == 'delete') {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Delete Store?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Are you sure you want to delete "${store.name}"? This action cannot be undone.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    if (shouldDelete == true) {
                      try {
                        await context.read<MusicStoreProvider>().deleteStore(
                          store.id,
                        );
                        Fluttertoast.showToast(
                          msg: "Store deleted successfully",
                        );
                      } catch (e) {
                        Fluttertoast.showToast(msg: "Error deleting store: $e");
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white70,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class StoreCard extends StatelessWidget {
  final MusicStoreModel store;
  final String? currentUserId;
  const StoreCard({required this.store, this.currentUserId, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    final isOwned = store.userId == currentUserId;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SongListScreen(store: store)),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: store.imageUrl.isNotEmpty
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            store.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _buildPlaceholder(),
              ),
            ),
            // Info Section
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isOwned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Your Store',
                            style: TextStyle(
                              color: Color(0xFFBB86FC),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Music Store',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.2),
            const Color(0xFF2A2A2A).withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.store, size: 40, color: accent),
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
