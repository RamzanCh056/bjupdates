import 'dart:convert';
import 'dart:io';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/order_screen/presentation/order_screen.dart';
import 'package:beatjerky/screens/store/store_product/product_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beatjerky/notification_services/email_service.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  static const String _storesCacheKey = 'store_screen_stores';
  List<Map<String, dynamic>> _stores = [];
  bool _loading = true;
  String? _error;

  late TabController _tabController;

  List<Map<String, dynamic>> get _myStores {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return [];
    return _stores.where((s) => s['userId'] == uid).toList();
  }

  List<Map<String, dynamic>> get _otherStores {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _stores;
    return _stores.where((s) => s['userId'] != uid).toList();
  }

  Map<String, dynamic> _storeToCacheJson(Map<String, dynamic> store) {
    final map = <String, dynamic>{};
    store.forEach((key, value) {
      map[key] = value is Timestamp ? value.millisecondsSinceEpoch : value;
    });
    return map;
  }

  Future<void> _loadStoresFromCacheOrFetch() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_storesCacheKey);
    bool hadValidCache = false;
    if (cached != null) {
      try {
        final list = jsonDecode(cached) as List;
        final loaded = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) {
          setState(() {
            _stores = _sortStoresWithMineFirst(loaded);
            _loading = false;
            _error = null;
          });
          hadValidCache = loaded.isNotEmpty;
        }
      } catch (e) {
        // ignore invalid cache
      }
    }
    if (!hadValidCache) await _fetchStores();
  }

  Future<void> _saveStoresToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _stores.map((s) => _storeToCacheJson(s)).toList();
      await prefs.setString(_storesCacheKey, jsonEncode(list));
    } catch (e) {
      // ignore
    }
  }

  List<Map<String, dynamic>> _sortStoresWithMineFirst(
    List<Map<String, dynamic>> list,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return list;
    final mine = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];
    for (final s in list) {
      if (s['userId'] == currentUserId) {
        mine.add(s);
      } else {
        others.add(s);
      }
    }
    return [...mine, ...others];
  }

  Future<void> _fetchStores() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await _firestore
          .collection('stores')
          .orderBy('created_at', descending: true)
          .get();
      if (!mounted) return;
      final raw = snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      setState(() {
        _stores = _sortStoresWithMineFirst(raw);
        _loading = false;
        _error = null;
      });
      await _saveStoresToCache();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStoresFromCacheOrFetch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddSheet() {
    if (!context.read<UserStatusProvider>().canManageVenueAndEvents) {
      AppToast.show(
        'Only Organizers and Venues can create venue/store profiles',
        isError: true,
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_business,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Create New Store',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFF3A3A3A)),
                  _AddStoreItemForm(
                    firestore: _firestore,
                    storage: _storage,
                    picker: _picker,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => _fetchStores());
  }

  void _openEditSheet(String storeId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF2A2A2A).withOpacity(0.9),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: appGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Edit Store',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFF3A3A3A)),
                  _EditStoreItemForm(
                    firestore: _firestore,
                    storage: _storage,
                    picker: _picker,
                    storeId: storeId,
                    initialData: data,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => _fetchStores());
  }

  Widget _buildStoreShimmer() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[850]!,
            highlightColor: Colors.grey[700]!,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Expanded(
                    flex: 3,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  // Text placeholders
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoresBody() {
    if (_error != null) {
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
                Icons.error_outline,
                size: 64,
                color: Color(0xFFBB86FC),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error Loading Stores',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    if (_loading && _stores.isEmpty) return _buildStoreShimmer();

    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(),
      children: [_buildOwnStoresTab(), _buildAllStoresTab()],
    );
  }

  Widget _buildOwnStoresTab() {
    final list = _myStores;
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
              'Create your first store to get started',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return _buildStoresGrid(list);
  }

  Widget _buildAllStoresTab() {
    final list = _otherStores;
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
              'Stores from others will appear here',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    return _buildStoresGrid(list);
  }

  Widget _buildStoresGrid(List<Map<String, dynamic>> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.95,
      ),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildStoreTile(list[i]),
    );
  }

  Widget _buildStoreTile(Map<String, dynamic> data) {
    final storeId = data['id'] as String;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = data['userId'] == currentUserId;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ProductScreen(storeId: storeId)),
        );
      },
      child: Stack(
        children: [
          _StoreCard(
            name: data['name']?.toString() ?? '',
            imageUrl: data['imageUrl']?.toString() ?? '',
            discount: data['discount']?.toString() ?? '',
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
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
                      final storeDoc = await _firestore
                          .collection('stores')
                          .doc(storeId)
                          .get();
                      if (!storeDoc.exists ||
                          storeDoc.data()?['userId'] != currentUserId) {
                        AppToast.show(
                          'You don\'t have permission to edit this store',
                          isError: true,
                        );
                        return;
                      }
                      _openEditSheet(storeId, Map<String, dynamic>.from(data));
                    } else if (value == 'delete') {
                      final shouldDelete = await showDialog<bool>(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF1F1F1F),
                                  const Color(0xFF2A2A2A).withOpacity(0.9),
                                ],
                              ),
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
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Delete Store',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Are you sure you want to delete this store? This action cannot be undone.',
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
                                            Navigator.pop(context, false),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          side: BorderSide(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
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
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
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
                                          elevation: 0,
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
                          final storeDoc = await _firestore
                              .collection('stores')
                              .doc(storeId)
                              .get();
                          if (!storeDoc.exists ||
                              storeDoc.data()?['userId'] != currentUserId) {
                            AppToast.show(
                              'You don\'t have permission to delete this store',
                              isError: true,
                            );
                            return;
                          }
                          await _firestore
                              .collection('stores')
                              .doc(storeId)
                              .delete();
                          AppToast.show('Store deleted successfully');
                          _fetchStores();
                        } catch (e) {
                          AppToast.show(
                            'Error deleting store: $e',
                            isError: true,
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                          SizedBox(width: 12),
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
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white70,
                            size: 22,
                          ),
                          SizedBox(width: 12),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = recntsColor;
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // leading: IconButton(
        //   icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        //   onPressed: () => Navigator.of(context).pop(),
        // ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              // padding: const EdgeInsets.all(8),
              // decoration: BoxDecoration(
              //   gradient: const LinearGradient(
              //     colors: [Color(0xFFBB86FC), Color(0xFF6200EE)],
              //   ),
              //   borderRadius: BorderRadius.circular(12),
              // ),
              // child: const Icon(
              //   Icons.store,
              //   color: Colors.white,
              //   size: 20,
              // ),
            ),
            // const SizedBox(width: 12),
            const Text(
              'Beat Jerky Store',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.inventory_2, color: Color(0xFFBB86FC)),
              onPressed: () async {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const OrderScreen()));
              },
            ),
          ),
        ],
        bottom: _error == null && !(_loading && _stores.isEmpty)
            ? PreferredSize(
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
              )
            : null,
      ),
      body: _buildStoresBody(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: appGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: recntsColor.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _openAddSheet,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name, imageUrl, discount;
  const _StoreCard({
    required this.name,
    required this.imageUrl,
    required this.discount,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F1F1F),
            const Color(0xFF2A2A2A).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Store Image
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withOpacity(0.3),
                              const Color(0xFF6200EE).withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.store,
                          size: 48,
                          color: Colors.white54,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withOpacity(0.3),
                            const Color(0xFF6200EE).withOpacity(0.3),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.store,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
            ),
          ),
          // Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
          ),
          // Discount Badge
          if (discount.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_offer,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$discount% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Store Name
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: accent,
                      size: 14,
                    ),
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

class _AddStoreItemForm extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker picker;

  const _AddStoreItemForm({
    required this.firestore,
    required this.storage,
    required this.picker,
  });

  @override
  State<_AddStoreItemForm> createState() => _AddStoreItemFormState();
}

class _AddStoreItemFormState extends State<_AddStoreItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _discountController = TextEditingController();
  XFile? _picked;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (img != null) setState(() => _picked = img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final discount = _discountController.text.trim();

    String imageUrl = '';
    if (_picked != null) {
      final ref = widget.storage.ref().child(
        'store_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(_picked!.path));
      imageUrl = await ref.getDownloadURL();
    }

    await widget.firestore.collection('stores').add({
      'name': name,
      'discount': int.parse(discount),
      'imageUrl': imageUrl,
      'created_at': Timestamp.now(),
      'userId': FirebaseAuth.instance.currentUser!.uid,
    });

    setState(() => _loading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.2),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _picked == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            color: accent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add Store Image',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to select (optional)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(_picked!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Name Field
          _buildTextField(
            controller: _nameController,
            hint: 'Store Name',
            icon: Icons.store,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter name' : null,
          ),
          const SizedBox(height: 16),
          // Discount Field
          _buildTextField(
            controller: _discountController,
            hint: 'Discount (%)',
            icon: Icons.local_offer,
            keyboardType: TextInputType.number,
            validator: (v) =>
                int.tryParse(v ?? '') == null ? 'Enter valid %' : null,
          ),
          const SizedBox(height: 28),
          // Create Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.add_business,
                      color: Colors.white,
                      size: 24,
                    ),
              label: Text(
                _loading ? 'Creating...' : 'Create Store',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _EditStoreItemForm extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseStorage storage;
  final ImagePicker picker;
  final String storeId;
  final Map<String, dynamic> initialData;

  const _EditStoreItemForm({
    required this.firestore,
    required this.storage,
    required this.picker,
    required this.storeId,
    required this.initialData,
  });

  @override
  State<_EditStoreItemForm> createState() => _EditStoreItemFormState();
}

class _EditStoreItemFormState extends State<_EditStoreItemForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _discountController;
  XFile? _picked;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData['name'] ?? '',
    );
    _discountController = TextEditingController(
      text: widget.initialData['discount']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await widget.picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (img != null) setState(() => _picked = img);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final name = _nameController.text.trim();
    final discount = _discountController.text.trim();

    String imageUrl = widget.initialData['imageUrl'] ?? '';
    if (_picked != null) {
      final ref = widget.storage.ref().child(
        'store_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(_picked!.path));
      imageUrl = await ref.getDownloadURL();
    }

    await widget.firestore.collection('stores').doc(widget.storeId).update({
      'name': name,
      'discount': int.parse(discount),
      'imageUrl': imageUrl,
    });

    setState(() => _loading = false);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: accent, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    final currentImageUrl = widget.initialData['imageUrl'] ?? '';

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Picker
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.2),
                    const Color(0xFF2A2A2A).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: _picked != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(_picked!.path),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  : currentImageUrl.isNotEmpty
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            currentImageUrl,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: const Color(0xFF2A2A2A),
                                  child: const Icon(
                                    Icons.store,
                                    size: 48,
                                    color: Colors.white54,
                                  ),
                                ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate,
                            color: accent,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentImageUrl.isNotEmpty
                              ? 'Change Store Image'
                              : 'Add Store Image',
                          style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to select (optional)',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Name Field
          _buildTextField(
            controller: _nameController,
            hint: 'Store Name',
            icon: Icons.store,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter name' : null,
          ),
          const SizedBox(height: 16),
          // Discount Field
          _buildTextField(
            controller: _discountController,
            hint: 'Discount (%)',
            icon: Icons.local_offer,
            keyboardType: TextInputType.number,
            validator: (v) =>
                int.tryParse(v ?? '') == null ? 'Enter valid %' : null,
          ),
          const SizedBox(height: 28),
          // Update Button
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: appGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white, size: 24),
              label: Text(
                _loading ? 'Updating...' : 'Update Store',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
