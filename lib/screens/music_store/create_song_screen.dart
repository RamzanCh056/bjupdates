import 'dart:io';

import 'package:beatjerky/screens/music_store/song_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/song_provider/song_provider.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';

class CreateSongScreen extends StatefulWidget {
  final String storeId;
  final SongModel? song;
  const CreateSongScreen({
    required this.storeId,
    this.song,
    Key? key,
  }) : super(key: key);

  @override
  State<CreateSongScreen> createState() => _CreateSongScreenState();
}

class _CreateSongScreenState extends State<CreateSongScreen> {
  final _form = GlobalKey<FormState>();
  final _titleC = TextEditingController();
  final _singerC = TextEditingController();
  final _descC = TextEditingController();
  final _priceC = TextEditingController();
  int _year = DateTime.now().year;
  File? _file, _cover;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.song != null) {
      _titleC.text = widget.song!.title;
      _singerC.text = widget.song!.singer;
      _descC.text = widget.song!.description;
      _priceC.text = widget.song!.price.toString();
      _year = widget.song!.year;
    }
  }

  @override
  void dispose() {
    _titleC.dispose();
    _singerC.dispose();
    _descC.dispose();
    _priceC.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (res != null) setState(() => _file = File(res.files.first.path!));
  }

  Future<void> _pickCover() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _cover = File(x.path));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (widget.song == null && _file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an MP3 file')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.song == null) {
        // Create new song
        await context.read<SongProvider>().addSong(
              storeId: widget.storeId,
              title: _titleC.text,
              singer: _singerC.text,
              description: _descC.text,
              price: double.parse(_priceC.text),
              year: _year,
              file: _file,
              coverImage: _cover,
            );
      } else {
        // Update existing song
        await context.read<SongProvider>().updateSong(
              songId: widget.song!.id,
              title: _titleC.text,
              singer: _singerC.text,
              description: _descC.text,
              price: double.parse(_priceC.text),
              year: _year,
              file: _file,
              coverImage: _cover,
            );
      }
      if (mounted) {
        Navigator.pop(context);
        AppToast.show(widget.song == null ? 'Song added successfully' : 'Song updated successfully');
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to ${widget.song == null ? 'add' : 'update'} song: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text(
          widget.song == null ? 'Add Song' : 'Edit Song',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 24,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Field
                  _buildTextField(
                    controller: _titleC,
                    label: 'Song Title',
                    icon: Icons.title,
                    validator: (v) => v!.isEmpty ? 'Enter song title' : null,
                  ),
                  const SizedBox(height: 16),
                  // Singer Field
                  _buildTextField(
                    controller: _singerC,
                    label: 'Singer/Artist',
                    icon: Icons.person_outline,
                    validator: (v) => v!.isEmpty ? 'Enter singer name' : null,
                  ),
                  const SizedBox(height: 16),
                  // Description Field
                  _buildTextField(
                    controller: _descC,
                    label: 'Description',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                    validator: (v) => v!.isEmpty ? 'Enter description' : null,
                  ),
                  const SizedBox(height: 16),
                  // Price Field
                  _buildTextField(
                    controller: _priceC,
                    label: 'Price',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    validator: (v) => double.tryParse(v!) == null ? 'Enter valid price' : null,
                  ),
                  const SizedBox(height: 24),
                  // MP3 File Picker
                  _buildFilePickerButton(
                    label: 'MP3 Audio File',
                    icon: Icons.audiotrack,
                    fileName: _file?.path.split('/').last,
                    onTap: _pickFile,
                    isSelected: _file != null,
                  ),
                  const SizedBox(height: 16),
                  // Cover Image Picker
                  _buildFilePickerButton(
                    label: 'Cover Image',
                    icon: Icons.image,
                    fileName: _cover?.path.split('/').last,
                    onTap: _pickCover,
                    isSelected: _cover != null,
                  ),
                  const SizedBox(height: 24),
                  // Year Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, color: accent.withOpacity(0.7), size: 22),
                        const SizedBox(width: 12),
                        const Text(
                          'Year:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<int>(
                          value: _year,
                          dropdownColor: const Color(0xFF1F1F1F),
                          icon: Icon(Icons.arrow_drop_down, color: accent),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          underline: Container(),
                          onChanged: _isLoading ? null : (v) => setState(() => _year = v!),
                          items: List.generate(
                            20,
                            (i) => DropdownMenuItem(
                              value: DateTime.now().year - i,
                              child: Text('${DateTime.now().year - i}'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Submit Button
                  Container(
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
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              widget.song == null ? Icons.add_circle_outline : Icons.save_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                      label: Text(
                        _isLoading
                            ? 'Processing...'
                            : widget.song == null
                                ? 'Add Song'
                                : 'Update Song',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFBB86FC),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilePickerButton({
    required String label,
    required IconData icon,
    String? fileName,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    const accent = Color(0xFFBB86FC);
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withOpacity(isSelected ? 0.2 : 0.1),
              const Color(0xFF2A2A2A).withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent.withOpacity(isSelected ? 0.5 : 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? accent : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSelected
                        ? (fileName ?? 'File selected')
                        : 'Tap to select file',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.arrow_forward_ios,
              color: isSelected ? Colors.green : Colors.white.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 14 : 16,
          horizontal: 16,
        ),
      ),
    );
  }
}
