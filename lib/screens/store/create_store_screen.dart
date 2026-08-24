import 'dart:io';

import 'package:beatjerky/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/music_store_provider/music_store_provider.dart';
import '../../utils/app_toast.dart';
import '../../utils/color.dart';
import '../music_store/music_store_model.dart';

class CreateStoreScreen extends StatefulWidget {
  /// If true, builds a music‐store form; otherwise a generic store form.
  final bool isMusicStore;
  final MusicStoreModel? store;

  const CreateStoreScreen({Key? key, this.isMusicStore = false, this.store})
    : super(key: key);

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  File? _pickedImage;
  String _name = '';
  String _discount = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.store != null) {
      _name = widget.store!.name;
      _discount = widget.store!.discount.toString();
    }
  }

  Future<void> _pickImage() async {
    final XFile? img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img != null) setState(() => _pickedImage = File(img.path));
  }

  Future<void> _submit() async {
    if (!context.read<UserStatusProvider>().canManageVenueAndEvents) {
      AppToast.show(
        'Only Organizers and Venues can create or manage venue/store profiles',
        isError: true,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (widget.store != null) {
        await Provider.of<MusicStoreProvider>(
          context,
          listen: false,
        ).updateStore(
          storeId: widget.store!.id,
          name: _name,
          discount: int.parse(_discount),
          imageFile: _pickedImage,
        );
      } else if (widget.isMusicStore) {
        await Provider.of<MusicStoreProvider>(
          context,
          listen: false,
        ).createMusicStore(name: _name, imageFile: _pickedImage);
      } else {
        await Provider.of<MusicStoreProvider>(context, listen: false).addStore(
          name: _name,
          discount: int.parse(_discount),
          imageFile: _pickedImage,
        );
      }
      Navigator.of(context).pop();
    } catch (e) {
      AppToast.show(
        'Error ${widget.store != null ? 'updating' : 'creating'} store: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: darkBackgroundPrimary,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        backgroundColor: darkAppBarBackground,
        elevation: 0,
        title: Text(
          widget.store != null ? 'Edit Store' : 'Create Store',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Picker
              GestureDetector(
                onTap: _isLoading ? null : _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(0.2),
                        const Color(0xFF2A2A2A).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: accent.withOpacity(0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: _pickedImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(
                                _pickedImage!,
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
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        )
                      : widget.store?.imageUrl.isNotEmpty == true
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                widget.store!.imageUrl,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildImagePlaceholder(),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(height: 24),
              // Store Name Field
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: accent.withOpacity(0.2),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildTextField(
                  label: 'Store Name',
                  icon: widget.isMusicStore ? Icons.music_note : Icons.store,
                  initialValue: _name,
                  onSaved: (v) => _name = v!.trim(),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a store name'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Discount Field (only for non-music stores)
              if (!widget.isMusicStore) ...[
                _buildTextField(
                  label: 'Discount (%)',
                  icon: Icons.local_offer,
                  initialValue: _discount,
                  keyboardType: TextInputType.number,
                  onSaved: (v) => _discount = v!.trim(),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null ? 'Enter a valid number' : null;
                  },
                ),
                const SizedBox(height: 28),
              ] else
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
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(
                          widget.store != null
                              ? Icons.save_outlined
                              : Icons.add_circle_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Processing...'
                        : widget.store != null
                        ? 'Update Store'
                        : 'Create Store',
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
    );
  }

  Widget _buildImagePlaceholder() {
    const accent = Color(0xFFBB86FC);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add_photo_alternate, color: accent, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          'Tap to Add Store Image',
          style: TextStyle(
            color: accent,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended: Landscape image',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    required FormFieldSetter<String> onSaved,
    required FormFieldValidator<String> validator,
  }) {
    const accent = Color(0xFFBB86FC);
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent.withOpacity(0.5), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
      ),
      onSaved: onSaved,
      validator: validator,
    );
  }
}
