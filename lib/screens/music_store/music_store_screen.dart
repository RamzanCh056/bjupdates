// import 'dart:io';
// import 'package:app/providers/music_store_provider/music_store_provider.dart';
// import 'package:app/screens/music_store/music_store_model.dart';
// import 'package:app/screens/music_store/song_list_screen.dart';
// import 'package:app/screens/store/create_store_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:provider/provider.dart';
//
// class StoreListScreen extends StatefulWidget {
//   const StoreListScreen({Key? key}) : super(key: key);
//   @override
//   State<StoreListScreen> createState() => _StoreListScreenState();
// }
//
// class _StoreListScreenState extends State<StoreListScreen> {
//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       context.read<MusicStoreProvider>().fetchStores();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final stores = context.watch<MusicStoreProvider>().stores;
//     return Scaffold(
//       appBar: AppBar(title: const Text('Music Stores')),
//       body: GridView.builder(
//         padding: const EdgeInsets.all(12),
//         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//           crossAxisCount: 2,
//           crossAxisSpacing: 12,
//           mainAxisSpacing: 12,
//           childAspectRatio: 0.8,
//         ),
//         itemCount: stores.length,
//         itemBuilder: (_, i) => InkWell(
//           onTap: () {
//             Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => SongListScreen(store: stores[i]),
//                 ));
//           },
//           child: StoreCard(store: stores[i]),
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStoreScreen())),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
//
// class StoreCard extends StatelessWidget {
//   final MusicStoreModel store;
//   const StoreCard({required this.store, Key? key}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       color: Colors.grey[900],
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Column(
//         children: [
//           Expanded(
//             child: store.imageUrl.isNotEmpty
//                 ? Image.network(store.imageUrl, fit: BoxFit.cover)
//                 : const Icon(Icons.store, size: 48, color: Colors.white24),
//           ),
//           Text(store.name, style: const TextStyle(color: Colors.white)),
//           Text('${store.discount}% off', style: const TextStyle(color: Colors.green)),
//         ],
//       ),
//     );
//   }
// }

import 'dart:io';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/screens/music_store/song_list_screen.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/music_store_provider/music_store_provider.dart';
import '../store/create_store_screen.dart';
import 'music_store_model.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({Key? key}) : super(key: key);

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicStoreProvider>().fetchStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stores = context.watch<MusicStoreProvider>().stores;
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: const Text(
          'Music Stores',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: stores.length,
        itemBuilder: (_, i) => InkWell(
          splashColor: Colors.white12,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SongListScreen(store: stores[i])),
          ),
          child: StoreCard(store: stores[i]),
        ),
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
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}

class StoreCard extends StatelessWidget {
  final MusicStoreModel store;
  const StoreCard({required this.store, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image or placeholder
          Expanded(
            child: store.imageUrl.isNotEmpty
                ? Image.network(store.imageUrl, fit: BoxFit.cover)
                : Container(
                    color: Colors.black,
                    child: const Icon(
                      Icons.store,
                      size: 48,
                      color: Colors.white24,
                    ),
                  ),
          ),
          // Footer with name & discount
          Container(
            // color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  store.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${store.discount}% off',
                  style: const TextStyle(color: Colors.greenAccent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
