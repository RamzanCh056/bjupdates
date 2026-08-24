import 'package:beatjerky/utils/app_toast.dart';
import 'package:beatjerky/utils/color.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class EventMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String eventName;
  final String? eventAddress;

  const EventMapScreen({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.eventName,
    this.eventAddress,
  }) : super(key: key);

  @override
  State<EventMapScreen> createState() => _EventMapScreenState();
}

class _EventMapScreenState extends State<EventMapScreen> {
  GoogleMapController? _mapController;
  String _address = '';
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _getAddressFromCoordinates();
  }

  Future<void> _getAddressFromCoordinates() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.latitude,
        widget.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = '${place.street}, ${place.locality}, ${place.administrativeArea}';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _address = 'Location coordinates: ${widget.latitude}, ${widget.longitude}';
      });
    }
  }

  Future<void> _openDirections() async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${widget.latitude},${widget.longitude}&travelmode=driving';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        AppToast.show('Could not open Google Maps', isError: true);
      }
    } catch (e) {
      AppToast.show('Error opening maps: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFBB86FC);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        ),
        title: Text(
          widget.eventName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(widget.latitude, widget.longitude),
                    zoom: 15.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    setState(() {
                      _isMapReady = true;
                    });
                  },
                  onTap: (LatLng position) {
                    // Handle map tap if needed
                    print('Map tapped at: $position');
                  },
                  markers: {
                    Marker(
                      markerId: MarkerId(widget.eventName),
                      position: LatLng(widget.latitude, widget.longitude),
                      infoWindow: InfoWindow(
                        title: widget.eventName,
                        snippet: _address.isNotEmpty ? _address : 'Event Location',
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
                      draggable: false,
                      flat: true,
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: true,
                  mapType: MapType.normal,
                  compassEnabled: true,
                  trafficEnabled: false,
                  buildingsEnabled: true,
                  indoorViewEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                ),
                // Loading overlay
                if (!_isMapReady)
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
          ),
          // Bottom info container
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F1F1F),
                  const Color(0xFF2A2A2A).withOpacity(0.9),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: appGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Event Location',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Address
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accent.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.eventAddress ?? _address,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.my_location,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
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
                const SizedBox(height: 16),
                // Get Directions button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: appGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openDirections,
                    icon: const Icon(Icons.directions, color: Colors.white, size: 22),
                    label: const Text(
                      'Get Directions',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
          onPressed: () {
            if (_mapController != null) {
              _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(
                  LatLng(widget.latitude, widget.longitude),
                  15.0,
                ),
              );
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.my_location, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
