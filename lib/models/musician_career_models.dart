import 'package:cloud_firestore/cloud_firestore.dart';

/// Data models for the Musician-Career feature.
///
/// These mirror the admin back-office schema (`beatjerky-admin/src/lib/types.ts`)
/// EXACTLY so the Flutter app and the Next.js admin read/write the same
/// Firestore documents. Keep the two in sync — a change here needs a matching
/// change there.
///
/// Conventions carried over from the admin:
///  * `musicians` are auto-id documents; `musicianId` == the doc id.
///    `userId` links the musician to an app-auth user ("" for admin
///    pre-registered musicians, filled in when the user claims the profile).
///  * Timestamps are stored as **int milliseconds** (JS `Date.now()`), NOT
///    Firestore `Timestamp`s. We write ints and defensively read ints,
///    `Timestamp`s, or ISO strings.
///  * Dropdown/multiselect/radio options are `{label, value}` pairs.

// ---------------------------------------------------------------------------
// Timestamp helpers (admin stores `Date.now()` numbers)
// ---------------------------------------------------------------------------

/// Reads a millisecond epoch int from any of: int, num, Firestore [Timestamp],
/// or an ISO-8601 string. Returns null when absent/unparseable.
int? readMillis(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is DateTime) return v.millisecondsSinceEpoch;
  if (v is String) {
    final asInt = int.tryParse(v);
    if (asInt != null) return asInt;
    final asDate = DateTime.tryParse(v);
    if (asDate != null) return asDate.millisecondsSinceEpoch;
  }
  return null;
}

/// Same as [readMillis] but returns a [DateTime].
DateTime? readDate(dynamic v) {
  final ms = readMillis(v);
  return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// MusicianRole = "drummer" | "vocalist" | "bassist" | "guitarist" | "other"
enum MusicianRole { drummer, vocalist, bassist, guitarist, other }

extension MusicianRoleX on MusicianRole {
  String get value {
    switch (this) {
      case MusicianRole.drummer:
        return 'drummer';
      case MusicianRole.vocalist:
        return 'vocalist';
      case MusicianRole.bassist:
        return 'bassist';
      case MusicianRole.guitarist:
        return 'guitarist';
      case MusicianRole.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case MusicianRole.drummer:
        return 'Drummer';
      case MusicianRole.vocalist:
        return 'Vocalist';
      case MusicianRole.bassist:
        return 'Bassist';
      case MusicianRole.guitarist:
        return 'Guitarist';
      case MusicianRole.other:
        return 'Other';
    }
  }

  static MusicianRole fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'drummer':
        return MusicianRole.drummer;
      case 'vocalist':
        return MusicianRole.vocalist;
      case 'bassist':
        return MusicianRole.bassist;
      case 'guitarist':
        return MusicianRole.guitarist;
      default:
        return MusicianRole.other;
    }
  }
}

/// ExperienceLevel = "beginner" | "intermediate" | "advanced" | "professional"
enum ExperienceLevel { beginner, intermediate, advanced, professional }

extension ExperienceLevelX on ExperienceLevel {
  String get value {
    switch (this) {
      case ExperienceLevel.beginner:
        return 'beginner';
      case ExperienceLevel.intermediate:
        return 'intermediate';
      case ExperienceLevel.advanced:
        return 'advanced';
      case ExperienceLevel.professional:
        return 'professional';
    }
  }

  String get label {
    switch (this) {
      case ExperienceLevel.beginner:
        return 'Beginner';
      case ExperienceLevel.intermediate:
        return 'Intermediate';
      case ExperienceLevel.advanced:
        return 'Advanced';
      case ExperienceLevel.professional:
        return 'Professional';
    }
  }

  static ExperienceLevel? fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'beginner':
        return ExperienceLevel.beginner;
      case 'intermediate':
        return ExperienceLevel.intermediate;
      case 'advanced':
        return ExperienceLevel.advanced;
      case 'professional':
        return ExperienceLevel.professional;
      default:
        return null;
    }
  }
}

/// FieldType =
///   "text" | "longtext" | "number" | "date" | "dropdown" | "multiselect" |
///   "checkbox" | "radio" | "file" | "image" | "document" | "medialink" |
///   "signature"
enum FieldType {
  text,
  longtext,
  number,
  date,
  dropdown,
  multiselect,
  checkbox,
  radio,
  file,
  image,
  document,
  medialink,
  signature,
}

extension FieldTypeX on FieldType {
  String get value {
    switch (this) {
      case FieldType.text:
        return 'text';
      case FieldType.longtext:
        return 'longtext';
      case FieldType.number:
        return 'number';
      case FieldType.date:
        return 'date';
      case FieldType.dropdown:
        return 'dropdown';
      case FieldType.multiselect:
        return 'multiselect';
      case FieldType.checkbox:
        return 'checkbox';
      case FieldType.radio:
        return 'radio';
      case FieldType.file:
        return 'file';
      case FieldType.image:
        return 'image';
      case FieldType.document:
        return 'document';
      case FieldType.medialink:
        return 'medialink';
      case FieldType.signature:
        return 'signature';
    }
  }

  static FieldType fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'longtext':
        return FieldType.longtext;
      case 'number':
        return FieldType.number;
      case 'date':
        return FieldType.date;
      case 'dropdown':
        return FieldType.dropdown;
      case 'multiselect':
        return FieldType.multiselect;
      case 'checkbox':
        return FieldType.checkbox;
      case 'radio':
        return FieldType.radio;
      case 'file':
        return FieldType.file;
      case 'image':
        return FieldType.image;
      case 'document':
        return FieldType.document;
      case 'medialink':
        return FieldType.medialink;
      case 'signature':
        return FieldType.signature;
      default:
        return FieldType.text;
    }
  }

  /// Field types that carry a list of selectable options.
  bool get hasOptions =>
      this == FieldType.dropdown ||
      this == FieldType.multiselect ||
      this == FieldType.radio;

  /// Field types whose answer is an uploaded file URL.
  bool get isUpload =>
      this == FieldType.file ||
      this == FieldType.image ||
      this == FieldType.document;
}

/// FormStatus =
///   "notStarted" | "inProgress" | "submitted" | "reviewed" |
///   "changesRequested" | "approved"
enum FormStatus {
  notStarted,
  inProgress,
  submitted,
  reviewed,
  changesRequested,
  approved,
}

extension FormStatusX on FormStatus {
  String get value {
    switch (this) {
      case FormStatus.notStarted:
        return 'notStarted';
      case FormStatus.inProgress:
        return 'inProgress';
      case FormStatus.submitted:
        return 'submitted';
      case FormStatus.reviewed:
        return 'reviewed';
      case FormStatus.changesRequested:
        return 'changesRequested';
      case FormStatus.approved:
        return 'approved';
    }
  }

  String get label {
    switch (this) {
      case FormStatus.notStarted:
        return 'Not started';
      case FormStatus.inProgress:
        return 'In progress';
      case FormStatus.submitted:
        return 'Submitted';
      case FormStatus.reviewed:
        return 'Reviewed';
      case FormStatus.changesRequested:
        return 'Changes requested';
      case FormStatus.approved:
        return 'Approved';
    }
  }

  static FormStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'inProgress':
        return FormStatus.inProgress;
      case 'submitted':
        return FormStatus.submitted;
      case 'reviewed':
        return FormStatus.reviewed;
      case 'changesRequested':
        return FormStatus.changesRequested;
      case 'approved':
        return FormStatus.approved;
      default:
        return FormStatus.notStarted;
    }
  }

  /// Whether the musician can still edit answers in this state.
  bool get isEditable =>
      this == FormStatus.notStarted ||
      this == FormStatus.inProgress ||
      this == FormStatus.changesRequested;
}

/// PaymentStatus =
///   "pending" | "partiallyPaid" | "paid" | "overdue" | "cancelled"
enum PaymentStatus { pending, partiallyPaid, paid, overdue, cancelled }

extension PaymentStatusX on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.partiallyPaid:
        return 'partiallyPaid';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.overdue:
        return 'overdue';
      case PaymentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partiallyPaid:
        return 'Partially paid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static PaymentStatus fromValue(dynamic v) {
    switch (v?.toString()) {
      case 'partiallyPaid':
        return PaymentStatus.partiallyPaid;
      case 'paid':
        return PaymentStatus.paid;
      case 'overdue':
        return PaymentStatus.overdue;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }
}

// ---------------------------------------------------------------------------
// Musician
// ---------------------------------------------------------------------------

/// A musician profile. Auto-id document in `musicians`; [id] == doc id.
/// [userId] links to the app-auth user ("" until claimed).
class Musician {
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String? phone;
  final String? location;
  final String? photoUrl;
  final MusicianRole primaryRole;
  final List<MusicianRole> secondaryRoles;
  final ExperienceLevel? experience;
  final List<String> genres;
  final String? bio;
  final String? availability;
  final List<MusicianLink> links;
  final int? createdAt;
  final int? updatedAt;

  const Musician({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    this.phone,
    this.location,
    this.photoUrl,
    this.primaryRole = MusicianRole.other,
    this.secondaryRoles = const [],
    this.experience,
    this.genres = const [],
    this.bio,
    this.availability,
    this.links = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Musician.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Musician.fromMap(doc.id, doc.data() ?? const {});

  factory Musician.fromMap(String id, Map<String, dynamic> data) {
    return Musician(
      id: id,
      userId: (data['userId'] ?? '').toString(),
      fullName: (data['fullName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      phone: data['phone']?.toString(),
      location: data['location']?.toString(),
      photoUrl: data['photoUrl']?.toString(),
      primaryRole: MusicianRoleX.fromValue(data['primaryRole']),
      secondaryRoles: (data['secondaryRoles'] as List?)
              ?.map((e) => MusicianRoleX.fromValue(e))
              .toList() ??
          const [],
      experience: ExperienceLevelX.fromValue(data['experience']),
      genres: List<String>.from(data['genres'] ?? const []),
      bio: data['bio']?.toString(),
      availability: data['availability']?.toString(),
      links: (data['links'] as List?)
              ?.map((e) =>
                  MusicianLink.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      createdAt: readMillis(data['createdAt']),
      updatedAt: readMillis(data['updatedAt']),
    );
  }

  /// Serialize for Firestore. Omits [id] (that's the doc id). Timestamps as
  /// int ms to match the admin. Pass [forCreate] to stamp createdAt.
  Map<String, dynamic> toMap({bool forCreate = false}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (location != null) 'location': location,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'primaryRole': primaryRole.value,
      'secondaryRoles': secondaryRoles.map((r) => r.value).toList(),
      if (experience != null) 'experience': experience!.value,
      'genres': genres,
      if (bio != null) 'bio': bio,
      if (availability != null) 'availability': availability,
      'links': links.map((l) => l.toMap()).toList(),
      'createdAt': forCreate ? now : (createdAt ?? now),
      'updatedAt': now,
    };
  }

  Musician copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? location,
    String? photoUrl,
    MusicianRole? primaryRole,
    List<MusicianRole>? secondaryRoles,
    ExperienceLevel? experience,
    List<String>? genres,
    String? bio,
    String? availability,
    List<MusicianLink>? links,
    int? createdAt,
    int? updatedAt,
  }) {
    return Musician(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      photoUrl: photoUrl ?? this.photoUrl,
      primaryRole: primaryRole ?? this.primaryRole,
      secondaryRoles: secondaryRoles ?? this.secondaryRoles,
      experience: experience ?? this.experience,
      genres: genres ?? this.genres,
      bio: bio ?? this.bio,
      availability: availability ?? this.availability,
      links: links ?? this.links,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// A labelled external link on a musician profile (e.g. Spotify, YouTube).
class MusicianLink {
  final String label;
  final String url;

  const MusicianLink({required this.label, required this.url});

  factory MusicianLink.fromMap(Map<String, dynamic> map) => MusicianLink(
        label: (map['label'] ?? '').toString(),
        url: (map['url'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'label': label, 'url': url};
}

// ---------------------------------------------------------------------------
// Form templates & fields
// ---------------------------------------------------------------------------

/// A selectable option on a dropdown/multiselect/radio field: `{label, value}`.
class FormFieldOption {
  final String label;
  final String value;

  const FormFieldOption({required this.label, required this.value});

  factory FormFieldOption.fromMap(Map<String, dynamic> map) => FormFieldOption(
        label: (map['label'] ?? '').toString(),
        value: (map['value'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {'label': label, 'value': value};
}

/// A condition gating a field's visibility on another field's value.
class FieldCondition {
  final String fieldId;
  final dynamic equals;

  const FieldCondition({required this.fieldId, required this.equals});

  factory FieldCondition.fromMap(Map<String, dynamic> map) => FieldCondition(
        fieldId: (map['fieldId'] ?? '').toString(),
        equals: map['equals'],
      );

  Map<String, dynamic> toMap() => {'fieldId': fieldId, 'equals': equals};
}

/// A single field within a form template.
class FormField {
  final String id;
  final FieldType type;
  final String label;
  final String? help;
  final bool required;
  final List<FormFieldOption> options;
  final num? min;
  final num? max;
  final FieldCondition? conditionalOn;

  const FormField({
    required this.id,
    required this.type,
    required this.label,
    this.help,
    this.required = false,
    this.options = const [],
    this.min,
    this.max,
    this.conditionalOn,
  });

  factory FormField.fromMap(Map<String, dynamic> map) {
    return FormField(
      id: (map['id'] ?? '').toString(),
      type: FieldTypeX.fromValue(map['type']),
      label: (map['label'] ?? '').toString(),
      help: map['help']?.toString(),
      required: map['required'] == true,
      options: (map['options'] as List?)
              ?.map((e) =>
                  FormFieldOption.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      min: map['min'] is num ? map['min'] as num : null,
      max: map['max'] is num ? map['max'] as num : null,
      conditionalOn: map['conditionalOn'] is Map
          ? FieldCondition.fromMap(
              Map<String, dynamic>.from(map['conditionalOn'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.value,
        'label': label,
        if (help != null) 'help': help,
        'required': required,
        if (options.isNotEmpty)
          'options': options.map((o) => o.toMap()).toList(),
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (conditionalOn != null) 'conditionalOn': conditionalOn!.toMap(),
      };
}

/// A form template authored in the admin. Rendered dynamically by the app.
class FormTemplate {
  final String id;
  final String title;
  final String? description;
  final int version;
  final List<String> roleTags;
  final List<FormField> fields;
  final bool active;
  final String createdBy;
  final int? createdAt;
  final int? updatedAt;

  const FormTemplate({
    required this.id,
    required this.title,
    this.description,
    this.version = 1,
    this.roleTags = const [],
    this.fields = const [],
    this.active = true,
    this.createdBy = '',
    this.createdAt,
    this.updatedAt,
  });

  factory FormTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FormTemplate.fromMap(doc.id, doc.data() ?? const {});

  factory FormTemplate.fromMap(String id, Map<String, dynamic> data) {
    return FormTemplate(
      id: id,
      title: (data['title'] ?? '').toString(),
      description: data['description']?.toString(),
      version: (data['version'] is num) ? (data['version'] as num).toInt() : 1,
      roleTags: List<String>.from(data['roleTags'] ?? const []),
      fields: (data['fields'] as List?)
              ?.map((e) =>
                  FormField.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      active: data['active'] != false,
      createdBy: (data['createdBy'] ?? '').toString(),
      createdAt: readMillis(data['createdAt']),
      updatedAt: readMillis(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        if (description != null) 'description': description,
        'version': version,
        'roleTags': roleTags,
        'fields': fields.map((f) => f.toMap()).toList(),
        'active': active,
        'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };
}

// ---------------------------------------------------------------------------
// Form assignments & submissions
// ---------------------------------------------------------------------------

/// Links a template to a musician: what they've been asked to fill in.
class FormAssignment {
  final String id;
  final String templateId;
  final int templateVersion;
  final String musicianId;
  final FormStatus status;
  final bool locked;
  final int? deadline;
  final String? linkToken;
  final String assignedBy;
  final int? assignedAt;
  final String userId;

  const FormAssignment({
    required this.id,
    required this.templateId,
    this.templateVersion = 1,
    required this.musicianId,
    this.status = FormStatus.notStarted,
    this.locked = false,
    this.deadline,
    this.linkToken,
    this.assignedBy = '',
    this.assignedAt,
    this.userId = '',
  });

  factory FormAssignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FormAssignment.fromMap(doc.id, doc.data() ?? const {});

  factory FormAssignment.fromMap(String id, Map<String, dynamic> data) {
    return FormAssignment(
      id: id,
      templateId: (data['templateId'] ?? '').toString(),
      templateVersion:
          (data['templateVersion'] is num) ? (data['templateVersion'] as num).toInt() : 1,
      musicianId: (data['musicianId'] ?? '').toString(),
      status: FormStatusX.fromValue(data['status']),
      locked: data['locked'] == true,
      deadline: readMillis(data['deadline']),
      linkToken: data['linkToken']?.toString(),
      assignedBy: (data['assignedBy'] ?? '').toString(),
      assignedAt: readMillis(data['assignedAt']),
      userId: (data['userId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'templateId': templateId,
        'templateVersion': templateVersion,
        'musicianId': musicianId,
        'status': status.value,
        'locked': locked,
        if (deadline != null) 'deadline': deadline,
        if (linkToken != null) 'linkToken': linkToken,
        'assignedBy': assignedBy,
        if (assignedAt != null) 'assignedAt': assignedAt,
        if (userId.isNotEmpty) 'userId': userId,
      };

  /// Whether the musician may edit this assignment's answers now.
  bool get isOpen => !locked && status.isEditable;
}

/// The answers a musician has entered/submitted for an assignment.
class FormSubmission {
  final String id;
  final String assignmentId;
  final String templateId;
  final String musicianId;
  final Map<String, dynamic> answers;
  final Map<String, String> files;
  final FormStatus status;
  final String? reviewerNote;
  final int? submittedAt;
  final int? updatedAt;
  final String userId;

  const FormSubmission({
    required this.id,
    required this.assignmentId,
    required this.templateId,
    required this.musicianId,
    this.answers = const {},
    this.files = const {},
    this.status = FormStatus.inProgress,
    this.reviewerNote,
    this.submittedAt,
    this.updatedAt,
    this.userId = '',
  });

  factory FormSubmission.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FormSubmission.fromMap(doc.id, doc.data() ?? const {});

  factory FormSubmission.fromMap(String id, Map<String, dynamic> data) {
    return FormSubmission(
      id: id,
      assignmentId: (data['assignmentId'] ?? '').toString(),
      templateId: (data['templateId'] ?? '').toString(),
      musicianId: (data['musicianId'] ?? '').toString(),
      answers: Map<String, dynamic>.from(data['answers'] ?? const {}),
      files: (data['files'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
      status: FormStatusX.fromValue(data['status']),
      reviewerNote: data['reviewerNote']?.toString(),
      submittedAt: readMillis(data['submittedAt']),
      updatedAt: readMillis(data['updatedAt']),
      userId: (data['userId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'assignmentId': assignmentId,
        'templateId': templateId,
        'musicianId': musicianId,
        'answers': answers,
        if (files.isNotEmpty) 'files': files,
        'status': status.value,
        if (reviewerNote != null) 'reviewerNote': reviewerNote,
        if (submittedAt != null) 'submittedAt': submittedAt,
        if (updatedAt != null) 'updatedAt': updatedAt,
        if (userId.isNotEmpty) 'userId': userId,
      };

  FormSubmission copyWith({
    Map<String, dynamic>? answers,
    Map<String, String>? files,
    FormStatus? status,
    String? reviewerNote,
    int? submittedAt,
    int? updatedAt,
    String? userId,
  }) {
    return FormSubmission(
      id: id,
      assignmentId: assignmentId,
      templateId: templateId,
      musicianId: musicianId,
      answers: answers ?? this.answers,
      files: files ?? this.files,
      status: status ?? this.status,
      reviewerNote: reviewerNote ?? this.reviewerNote,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}
