// class EventModelFields {
//   static const String id = "id";
//   static const String eventName = "eventName";
//   static const String artistName = "artistName";
//   static const String eventPlace = "eventPlace";
//   static const String eventStartTime = "eventStartTime";
//   static const String eventEndTime = "eventEndTime";
//   static const String picturePath = "picturePath";
//   static const String longitude = "longitude";
//   static const String latitude = "latitude";
//   static const String address = "address"; // Add address field
//   static const String artistProfileId = "artistProfileId";
//   static const String clientId="clientId";
//   static const String updatedAt = "updatedAt";
//   static const String createdAt = "createdAt";

// }

// class EventModel {
//   final int id;
//   final String eventName;
//   final String artistName;
//   final String eventPlace;
//   final String eventStartTime;
//   final String eventEndTime;
//   final String picturePath;
//   final String longitude;
//   final String latitude;
//   final String? address; // Add address field
//   final int artistProfileId;
//   final String updatedAt;
//   final String createdAt;
//   final String? clientId;


//   EventModel({
//     required this.id,
//     required this.eventName,
//     required this.artistName,
//     required this.eventPlace,
//     required this.eventStartTime,
//     required this.eventEndTime,
//     required this.picturePath,
//     required this.longitude,
//     required this.latitude,
//     this.address, // Make address optional
//     required this.artistProfileId,
//     required this.updatedAt,
//     required this.createdAt,
//     required this.clientId
//   });

//   factory EventModel.fromJson(Map<String, dynamic> json)=>
//       EventModel(
//           id: json[EventModelFields.id],
//           eventName: json[EventModelFields.eventName],
//           artistName: json[EventModelFields.artistName],
//           eventPlace: json[EventModelFields.eventPlace],
//           eventStartTime: json[EventModelFields.eventStartTime],
//           eventEndTime: json[EventModelFields.eventEndTime],
//           picturePath: json[EventModelFields.picturePath],
//           longitude: json[EventModelFields.longitude],
//           latitude: json[EventModelFields.latitude],
//           address: json[EventModelFields.address], // Parse address from JSON
//           artistProfileId: json[EventModelFields.artistProfileId],
//           updatedAt: json[EventModelFields.updatedAt],
//           createdAt: json[EventModelFields.createdAt],
//         clientId: json[EventModelFields.clientId]
//       );

// }