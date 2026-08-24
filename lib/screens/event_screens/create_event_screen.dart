import 'dart:convert';
import 'dart:io';
import 'package:beatjerky/Stripe/SubscriptionHelper.dart';
import 'package:beatjerky/Stripe/SubscriptionServicefull.dart';
import 'package:beatjerky/providers/user_provider.dart';
import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'event_model.dart';
import 'event_service.dart';
import 'map_location_picker.dart';

class CreateEventScreen extends StatefulWidget {
  final Event1Model? event;

  const CreateEventScreen({Key? key, this.event}) : super(key: key);

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  File? _image;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final SubscriptionServicefull _subscriptionService =
      SubscriptionServicefull();
  String? _startTime;
  String? _endTime;
  DateTime? _selectedDate;
  bool _loading = false;
  bool _isCheckingPermission = true;

  // Map location variables
  double? _selectedLatitude;
  double? _selectedLongitude;
  String _selectedAddress = '';
  bool _isLocationSelected = false;

  @override
  void initState() {
    super.initState();

    // Initialize with existing event data if editing
    if (widget.event != null) {
      _artistController.text = widget.event!.artistName;
      _nameController.text = widget.event!.eventName;
      _placeController.text = widget.event!.place;
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _selectedDate = DateTime.parse(widget.event!.date);
      _selectedLatitude = widget.event!.latitude;
      _selectedLongitude = widget.event!.longitude;
      _selectedAddress = widget.event!.place;
      _isLocationSelected =
          widget.event!.latitude != null && widget.event!.longitude != null;
    }

    // Check permission after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserPermission();
    });
  }

  Future<void> _checkUserPermission() async {
    final userProvider = context.read<UserStatusProvider>();

    // If still loading, wait a bit and check again
    if (userProvider.loading) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppToast.show('Location permission denied', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppToast.show(
          'Location permissions are permanently denied',
          isError: true,
        );
        return;
      }

      AppToast.show('Getting current location...', isError: false);

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            '${place.street}, ${place.locality}, ${place.administrativeArea}';

        setState(() {
          _selectedLatitude = position.latitude;
          _selectedLongitude = position.longitude;
          _selectedAddress = address;
          _placeController.text = address;
          _isLocationSelected = true;
        });

        AppToast.show('Location captured successfully!', isError: false);
      }
    } catch (e) {
      AppToast.show('Error getting location: $e', isError: true);
    }
  }

  // Open map picker
  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapLocationPicker(
          initialLatitude: _selectedLatitude ?? 30.3753,
          initialLongitude: _selectedLongitude ?? 69.3451,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result['latitude'];
        _selectedLongitude = result['longitude'];
        _selectedAddress = result['address'];
        _placeController.text = result['address'];
        _isLocationSelected = true;
      });
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    // Check if selected date is today to prevent past times
    bool isToday =
        _selectedDate != null &&
        _selectedDate!.year == DateTime.now().year &&
        _selectedDate!.month == DateTime.now().month &&
        _selectedDate!.day == DateTime.now().day;

    TimeOfDay initialTime = TimeOfDay.now();
    if (isStart && isToday) {
      // For start time on today, add 1 hour to current time
      final now = DateTime.now();
      initialTime = TimeOfDay(hour: now.hour + 1, minute: now.minute);
    }

    final TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1F1F1F),
              hourMinuteColor: MaterialStateColor.resolveWith(
                (states) => const Color(0xFF2A2A2A),
              ),
              hourMinuteTextColor: MaterialStateColor.resolveWith(
                (states) => Colors.white,
              ),
              dialHandColor: const Color(0xFFBB86FC),
              dialBackgroundColor: const Color(0xFF2A2A2A),
              entryModeIconColor: Colors.white,
            ),
            colorScheme: ColorScheme.dark(primary: const Color(0xFFBB86FC)),
          ),
          child: child!,
        );
      },
    );
    if (t != null) {
      setState(() {
        final formatted = t.format(context);
        if (isStart)
          _startTime = formatted;
        else
          _endTime = formatted;
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), // Only allow dates from today onwards
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFFBB86FC),
              onPrimary: Colors.white,
              surface: const Color(0xFF1F1F1F),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF121212),
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  // Method to check permissions
  bool _hasPermissionToCreateEvent(UserStatusProvider userProvider) {
    return userProvider.canManageVenueAndEvents;
  }

  void _handleCreateEventButtonClick(UserStatusProvider userProvider) {
    // Check if user has permission
    if (!_hasPermissionToCreateEvent(userProvider)) {
      String roleMessage = userProvider.roles.isEmpty
          ? 'You don\'t have any role assigned.'
          : 'Your current role(s): ${userProvider.roles.join(", ")}.';

      AppToast.show(
        'You don\'t have permission to create events. Only Organizers and Venues can create events. $roleMessage',
        isError: true,
      );
      return;
    }

    // If user has permission, proceed with form validation and submission
    _submitForm(userProvider);
  }

  Future<void> _submitForm(UserStatusProvider userProvider) async {
    // Debug print to check current state
    print('🔍 User Status Check at Submit:');
    print('   - Loading: ${userProvider.loading}');
    print('   - Roles: ${userProvider.roles}');
    print('   - Active Role: ${userProvider.activeRole}');
    print('   - Effective Roles: ${userProvider.effectiveRoles}');
    print('   - Can Manage: ${userProvider.canManageVenueAndEvents}');

    // Check if still loading
    if (userProvider.loading) {
      AppToast.show(
        'Loading user data... please wait a moment',
        isError: false,
      );
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      AppToast.show('Please fill all required fields', isError: true);
      return;
    }

    // Validate time fields
    if (_startTime == null || _endTime == null) {
      AppToast.show('Please select start and end times', isError: true);
      return;
    }

    // Validate date
    if (_selectedDate == null) {
      AppToast.show('Please select a date', isError: true);
      return;
    }

    // Validate location
    if (!_isLocationSelected) {
      AppToast.show('Please select a location on the map', isError: true);
      return;
    }

    // Validate image for new events
    if (widget.event == null && _image == null) {
      AppToast.show('Please select an event image', isError: true);
      return;
    }

    // Validate that event date and time are not in the past
    final now = DateTime.now();
    final timeParts = _startTime!.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1].split(' ')[0]);

    final eventDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      hour,
      minute,
    );

    if (eventDateTime.isBefore(now)) {
      AppToast.show(
        'Event cannot be scheduled in the past. Please select a future date and time.',
        isError: true,
      );
      return;
    }

    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      if (widget.event == null) {
        // Create new event
        await EventService().createEvent(
          artistName: _artistController.text.trim(),
          eventName: _nameController.text.trim(),
          place: _placeController.text.trim(),
          startTime: _startTime!,
          endTime: _endTime!,
          date:
              '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
          imageFile: _image!,
          ownerId: uid,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          address: _selectedAddress,
        );
      } else {
        // Update existing event
        await EventService().updateEvent(
          eventId: widget.event!.id,
          artistName: _artistController.text.trim(),
          eventName: _nameController.text.trim(),
          place: _placeController.text.trim(),
          startTime: _startTime!,
          endTime: _endTime!,
          date:
              '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
          newImageFile: _image,
          latitude: _selectedLatitude,
          longitude: _selectedLongitude,
          address: _selectedAddress,
        );
      }

      if (mounted) {
        AppToast.show('Event saved successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildImagePlaceholder(String text) {
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
          text,
          style: const TextStyle(
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

  InputDecoration _inputDecoration(
    String label,
    IconData icon, {
    Widget? suffix,
  }) {
    const accent = Color(0xFFBB86FC);

    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
      prefixIcon: Icon(icon, color: accent.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent.withOpacity(0.5), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      suffixIcon: suffix,
    );
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
        centerTitle: true,
        title: Text(
          widget.event == null ? 'Create Event' : 'Edit Event',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Consumer<UserStatusProvider>(
        builder: (context, userProvider, child) {
          // Show loading while checking permissions
          if (userProvider.loading || _isCheckingPermission) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFFBB86FC)),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Show the actual form for ALL users (no screen-level restriction)
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Optional: Show role info banner (can be removed if not needed)
                
                  // Image picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFBB86FC).withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _image != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.file(
                                    _image!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
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
                          : widget.event != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                widget.event!.imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFBB86FC),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) =>
                                    _buildImagePlaceholder(
                                      'Click to Change Event Photo',
                                    ),
                              ),
                            )
                          : _buildImagePlaceholder('Tap to Add Event Photo'),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Artist name field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accent.withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _artistController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _inputDecoration(
                        'Artist Name',
                        Icons.person_outline,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Artist name is required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Event name field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accent.withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _inputDecoration('Event Name', Icons.event),
                      validator: (v) =>
                          v!.isEmpty ? 'Event name is required' : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location selection section
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accent.withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBB86FC).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFBB86FC),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Event Location',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Location input field
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            controller: _placeController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Select event location',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                  color: const Color(
                                    0xFFBB86FC,
                                  ).withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.place,
                                color: Color(0xFFBB86FC),
                                size: 22,
                              ),
                              suffixIcon: Icon(
                                _isLocationSelected
                                    ? Icons.check_circle
                                    : Icons.arrow_forward_ios,
                                color: _isLocationSelected
                                    ? Colors.green
                                    : Colors.white.withOpacity(0.5),
                                size: 20,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 16,
                              ),
                            ),
                            readOnly: true,
                            onTap: _openMapPicker,
                            validator: (v) =>
                                v!.isEmpty ? 'Please select a location' : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Location action buttons
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFBB86FC).withOpacity(0.2),
                                      const Color(0xFF6200EE).withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFBB86FC,
                                    ).withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _openMapPicker,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.map,
                                            color: Color(0xFFBB86FC),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Pick on Map',
                                            style: TextStyle(
                                              color: Color(0xFFBB86FC),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFFBB86FC).withOpacity(0.2),
                                      const Color(0xFF6200EE).withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFBB86FC,
                                    ).withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _getCurrentLocation,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.my_location,
                                            color: Color(0xFFBB86FC),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Current Location',
                                            style: TextStyle(
                                              color: Color(0xFFBB86FC),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Show selected coordinates if available
                        if (_isLocationSelected) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.2),
                                  Colors.green.withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Location Selected',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_selectedLatitude?.toStringAsFixed(6)}, ${_selectedLongitude?.toStringAsFixed(6)}',
                                        style: TextStyle(
                                          color: Colors.green.withOpacity(0.8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Time and Date section
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: _inputDecoration(
                              'Start Time',
                              Icons.access_time,
                              suffix: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                            onTap: () => _pickTime(isStart: true),
                            controller: TextEditingController(text: _startTime),
                            validator: (v) =>
                                v!.isEmpty ? 'Start time is required' : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: accent.withOpacity(0.2),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextFormField(
                            readOnly: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            decoration: _inputDecoration(
                              'End Time',
                              Icons.access_time,
                              suffix: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white54,
                                size: 24,
                              ),
                            ),
                            onTap: () => _pickTime(isStart: false),
                            controller: TextEditingController(text: _endTime),
                            validator: (v) =>
                                v!.isEmpty ? 'End time is required' : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date field
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: accent.withOpacity(0.2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      readOnly: true,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: _inputDecoration(
                        'Event Date',
                        Icons.calendar_today,
                        suffix: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
                      onTap: _pickDate,
                      controller: TextEditingController(
                        text: _selectedDate == null
                            ? ''
                            : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                      ),
                      validator: (v) => v!.isEmpty ? 'Date is required' : null,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Submit button with role restriction ONLY HERE
                  Container(
                    decoration: BoxDecoration(
                      gradient: appGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBB86FC).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SubscriptionGuard(
                      userEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                      onSubscribe: (context, email) async {
                        await _subscriptionService.showSubscriptionPopup(
                          context,
                          email,
                        );
                      },
                      child: ElevatedButton(
                        onPressed: _loading
                            ? null
                            : () => _handleCreateEventButtonClick(userProvider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _loading
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
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.event == null
                                        ? Icons.add_circle_outline
                                        : Icons.save_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.event == null
                                        ? 'Create Event'
                                        : 'Update Event',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
