import 'package:beatjerky/utils/app_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../model/api_models/all_categories/all_category_song_model.dart';
import '../providers/music_style_provider/music_style_provider.dart';
import '../shimmer_effect/recently_music_screen_skeleton.dart';
import '../utils/color.dart';
import '../widget/reusable_text.dart';
import '../widget/reusable_textformfield.dart';
import 'audio_player.dart';

class RecentlyMusicScreen extends StatefulWidget {
  const RecentlyMusicScreen({
    required this.id,
    required this.title,
    Key? key,
  }) : super(key: key);

  final String title;
  final int id;

  @override
  State<RecentlyMusicScreen> createState() => _RecentlyMusicScreenState();
}

class _RecentlyMusicScreenState extends State<RecentlyMusicScreen> {
  final songTitleController = TextEditingController();
  final singerNameController = TextEditingController();
  final songDescriptionController = TextEditingController();

  FilePickerResult? musicFile;
  String selectedCategory = "";
  int selectedYear = DateTime.now().year;

  bool isLoading = true;
  List<CategoriesSongModel> songsList = [];

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    // await MusicStyleServices().getMusicStylesById(widget.id, context);
    songsList = Provider.of<MusicStyleProvider>(context, listen: false).songsInCategoryList;
    setState(() => isLoading = false);
  }

  Future<void> pickSong() async {
    musicFile = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wmv'],
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SafeArea(
      child: Scaffold(
        backgroundColor: blackColor,
        appBar: AppBar(
          backgroundColor: blackColor,
          elevation: 0,
          centerTitle: true,
          title: ReusableText(
            title: widget.title,
            color: whiteColor,
            size: 20,
            weight: FontWeight.bold,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              onPressed: () => _showAddSongSheet(context, screenHeight),
            )
          ],
        ),
        body: isLoading
            ? const RecentlyMusicScreenSkeleton()
            : ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: songsList.length,
                itemBuilder: (ctx, i) {
                  final song = songsList[i];
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AudioPlay(),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          ReusableText(
                            title: '${i + 1}.',
                            color: whiteColor,
                            size: 18,
                          ),
                          const SizedBox(width: 20),
                          Container(
                            height: 60,
                            width: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: song.coverImageURL != null
                                    ? NetworkImage(song.coverImageURL!)
                                    : const AssetImage(
                                        'assets/images/logo.png',
                                      ) as ImageProvider,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ReusableText(
                                  title: song.title,
                                  color: whiteColor,
                                  size: 16,
                                  weight: FontWeight.bold,
                                ),
                                ReusableText(
                                  title: song.descriptionOfSong.length > 10
                                      ? '${song.descriptionOfSong.substring(0, 11)}…'
                                      : song.descriptionOfSong,
                                  color: greyColor,
                                  size: 14,
                                  weight: FontWeight.w500,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.more_vert, color: whiteColor),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showAddSongSheet(BuildContext context, double screenHeight) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: blackColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSb) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: whiteColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),

                    // File picker
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: InkWell(
                        onTap: () async {
                          await pickSong();
                          setSb(() {});
                        },
                        child: Text(
                          musicFile == null ? 'Choose MP3/WAV Song' : musicFile!.names.first ?? 'File Selected',
                          style: TextStyle(color: whiteColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Singer Name
                    ReusableTextForm(
                      controller: singerNameController,
                      hintText: 'Enter Singer Name',
                      filledColor: Colors.grey[850]!,
                      onChanged: (_) => setSb(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Song Title
                    ReusableTextForm(
                      controller: songTitleController,
                      hintText: 'Enter Song Title',
                      filledColor: Colors.grey[850]!,
                      onChanged: (_) => setSb(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Song Description
                    ReusableTextForm(
                      controller: songDescriptionController,
                      hintText: 'Enter Description',
                      filledColor: Colors.grey[850]!,
                      onChanged: (_) => setSb(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Year selector
                    Row(
                      children: [
                        const Text('Year of Song: ', style: TextStyle(color: whiteColor)),
                        const SizedBox(width: 12),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            dropdownColor: Colors.grey[900],
                            value: selectedYear,
                            items: List.generate(50, (i) {
                              final year = DateTime.now().year - i;
                              return DropdownMenuItem(
                                value: year,
                                child: Text('$year', style: TextStyle(color: whiteColor)),
                              );
                            }),
                            onChanged: (y) {
                              selectedYear = y!;
                              setSb(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Upload button
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.green)
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: indigoColor,
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              setSb(() => isLoading = true);
                              if (musicFile == null) {
                                setSb(() => isLoading = false);
                                AppToast.show('Please select a song file.', isError: true);
                                return;
                              }
                              // final response = await UserSongServices().addSong(
                              //   context,
                              //   songTitle: songTitleController.text,
                              //   songDescription: songDescriptionController.text,
                              //   singer: singerNameController.text,
                              //   musicPath: musicFile!.paths.first!,
                              //   categoryId: widget.id.toString(),
                              //   year: selectedYear.toString(),
                              // );
                              // if (response) {
                              //   await _loadSongs();
                              //   Navigator.pop(ctx);
                              // } else {
                              //   Get.showSnackbar(const GetSnackBar(
                              //     message: 'Upload failed.',
                              //     duration: Duration(seconds: 2),
                              //   ));
                              //   setSb(() => isLoading = false);
                              // }
                            },
                            child: const Text(
                              'Upload Song',
                              style: TextStyle(color: whiteColor, fontSize: 16),
                            ),
                          ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
