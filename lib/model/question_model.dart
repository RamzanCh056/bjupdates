import 'package:cloud_firestore/cloud_firestore.dart';

class QuestionOption {
  final String id;
  final String text;
  final int votes;
  final List<String> voters; // List of user IDs who voted for this option

  QuestionOption({
    required this.id,
    required this.text,
    this.votes = 0,
    this.voters = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'votes': votes,
      'voters': voters,
    };
  }

  factory QuestionOption.fromMap(Map<String, dynamic> map) {
    return QuestionOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      votes: (map['votes'] ?? 0).toInt(),
      voters: List<String>.from(map['voters'] ?? []),
    );
  }

  QuestionOption copyWith({
    String? id,
    String? text,
    int? votes,
    List<String>? voters,
  }) {
    return QuestionOption(
      id: id ?? this.id,
      text: text ?? this.text,
      votes: votes ?? this.votes,
      voters: voters ?? this.voters,
    );
  }
}

class QuestionPost {
  final String id;
  final String userId;
  final String userFirstName;
  final String userSecondName;
  final String userImage;
  final String question;
  final String? location;
  final List<QuestionOption> options;
  final int totalVotes;
  final DateTime timestamp;
  final List<String> tags;
  final bool isActive; // Whether the question is still accepting votes
  final DateTime? expiresAt; // Optional expiration date

  QuestionPost({
    required this.id,
    required this.userId,
    required this.userFirstName,
    required this.userSecondName,
    required this.userImage,
    required this.question,
    this.location,
    required this.options,
    this.totalVotes = 0,
    required this.timestamp,
    this.tags = const [],
    this.isActive = true,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userFirstName': userFirstName,
      'userSecondName': userSecondName,
      'userImage': userImage,
      'question': question,
      'location': location,
      'options': options.map((option) => option.toMap()).toList(),
      'totalVotes': totalVotes,
      'timestamp': timestamp,
      'tags': tags,
      'isActive': isActive,
      'expiresAt': expiresAt,
    };
  }

  factory QuestionPost.fromMap(Map<String, dynamic> map) {
    return QuestionPost(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userFirstName: map['userFirstName'] ?? '',
      userSecondName: map['userSecondName'] ?? '',
      userImage: map['userImage'] ?? '',
      question: map['question'] ?? '',
      location: map['location'],
      options: (map['options'] as List<dynamic>?)
          ?.map((option) => QuestionOption.fromMap(option))
          .toList() ?? [],
      totalVotes: (map['totalVotes'] ?? 0).toInt(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(map['tags'] ?? []),
      isActive: map['isActive'] ?? true,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  QuestionPost copyWith({
    String? id,
    String? userId,
    String? userFirstName,
    String? userSecondName,
    String? userImage,
    String? question,
    String? location,
    List<QuestionOption>? options,
    int? totalVotes,
    DateTime? timestamp,
    List<String>? tags,
    bool? isActive,
    DateTime? expiresAt,
  }) {
    return QuestionPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userFirstName: userFirstName ?? this.userFirstName,
      userSecondName: userSecondName ?? this.userSecondName,
      userImage: userImage ?? this.userImage,
      question: question ?? this.question,
      location: location ?? this.location,
      options: options ?? this.options,
      totalVotes: totalVotes ?? this.totalVotes,
      timestamp: timestamp ?? this.timestamp,
      tags: tags ?? this.tags,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
