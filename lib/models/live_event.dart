class LiveEvent {
  final String title;
  final String description;
  final String url;
  final String? imageUrl;

  const LiveEvent({
    required this.title,
    required this.description,
    required this.url,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'url': url,
        'imageUrl': imageUrl,
      };

  factory LiveEvent.fromJson(Map<String, dynamic> json) {
    return LiveEvent(
      title: json['title'] as String? ?? 'Event',
      description: json['description'] as String? ?? '',
      url: json['url'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

enum LiveEventsLoadState {
  loading,
  loaded,
  locationDenied,
  empty,
  error,
}

class LiveEventsResult {
  final LiveEventsLoadState state;
  final List<LiveEvent> events;
  final String? cityName;
  final bool usedFallbackLocation;

  const LiveEventsResult({
    required this.state,
    this.events = const [],
    this.cityName,
    this.usedFallbackLocation = false,
  });
}
