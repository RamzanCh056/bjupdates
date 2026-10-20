// lib/models/event_model.dart

class Event1Model {
  final String id;
  final String imageUrl;
  final String artistName;
  final String eventName;
  final String place;
  final String startTime;
  final String endTime;
  final String date;
  final String ownerId;
  final double? latitude; // Add latitude for map location
  final double? longitude; // Add longitude for map location
  final String? address; // Add address for human-readable location

  Event1Model({
    required this.id,
    required this.imageUrl,
    required this.artistName,
    required this.eventName,
    required this.place,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.ownerId,
    this.latitude, // Optional for backward compatibility
    this.longitude, // Optional for backward compatibility
    this.address, // Optional for backward compatibility
  });

  /// Creates an EventModel from a Firestore document map.
  factory Event1Model.fromMap(String id, Map<String, dynamic> data) {
    return Event1Model(
      id: id,
      imageUrl: data['imageUrl'] as String,
      artistName: data['artistName'] as String,
      eventName: data['eventName'] as String,
      place: data['place'] as String,
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      date: data['date'] as String,
      ownerId: data['ownerId'] as String,
      latitude: data['latitude']?.toDouble(), // Parse latitude if available
      longitude: data['longitude']?.toDouble(), // Parse longitude if available
      address: data['address'] as String?, // Parse address if available
    );
  }

  /// Converts this EventModel into a map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'artistName': artistName,
      'eventName': eventName,
      'place': place,
      'startTime': startTime,
      'endTime': endTime,
      'date': date,
      'ownerId': ownerId,
      'latitude': latitude, // Include latitude in Firestore
      'longitude': longitude, // Include longitude in Firestore
      'address': address, // Include address in Firestore
    };
  }
}
