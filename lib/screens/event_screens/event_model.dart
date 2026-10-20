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
  final double? latitude;
  final double? longitude;
  final String? address;

  // Event-planning extras (all optional / backward-compatible)
  final num? budget;
  final num? attendance;
  final List<String> staffNeeded;
  final List<String> suppliers;
  final List<String> permits;
  final String? notes;

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
    this.latitude,
    this.longitude,
    this.address,
    this.budget,
    this.attendance,
    this.staffNeeded = const [],
    this.suppliers = const [],
    this.permits = const [],
    this.notes,
  });

  static List<String> _stringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const [];

  /// Creates an EventModel from a Firestore document map.
  factory Event1Model.fromMap(String id, Map<String, dynamic> data) {
    return Event1Model(
      id: id,
      imageUrl: (data['imageUrl'] ?? '') as String,
      artistName: (data['artistName'] ?? '') as String,
      eventName: (data['eventName'] ?? '') as String,
      place: (data['place'] ?? '') as String,
      startTime: (data['startTime'] ?? '') as String,
      endTime: (data['endTime'] ?? '') as String,
      date: (data['date'] ?? '') as String,
      ownerId: (data['ownerId'] ?? '') as String,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      address: data['address'] as String?,
      budget: data['budget'] as num?,
      attendance: data['attendance'] as num?,
      staffNeeded: _stringList(data['staffNeeded']),
      suppliers: _stringList(data['suppliers']),
      permits: _stringList(data['permits']),
      notes: data['notes'] as String?,
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
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'budget': budget,
      'attendance': attendance,
      'staffNeeded': staffNeeded,
      'suppliers': suppliers,
      'permits': permits,
      'notes': notes,
    };
  }
}
