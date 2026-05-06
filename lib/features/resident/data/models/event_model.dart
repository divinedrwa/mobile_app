import '../../../../core/constants/app_constants.dart';

/// Event model
class EventModel {
  final String id;
  final String title;
  final String description;
  final EventCategory category;
  final DateTime startTime;
  final DateTime endTime;
  final String location;
  final String? imageUrl;
  final int? maxAttendees;
  final int currentAttendees;
  final bool isRegistered;
  final bool requiresRegistration;
  final String? organizer;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.imageUrl,
    this.maxAttendees,
    this.currentAttendees = 0,
    this.isRegistered = false,
    this.requiresRegistration = true,
    this.organizer,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: EventCategory.values.firstWhere(
        (e) => e.value == json['category'],
        orElse: () => EventCategory.social,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      location: json['location'] as String,
      imageUrl: json['imageUrl'] as String?,
      maxAttendees: json['maxAttendees'] as int?,
      currentAttendees: json['currentAttendees'] as int? ?? 0,
      isRegistered: json['isRegistered'] as bool? ?? false,
      requiresRegistration: json['requiresRegistration'] as bool? ?? true,
      organizer: json['organizer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.value,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'location': location,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (maxAttendees != null) 'maxAttendees': maxAttendees,
      'currentAttendees': currentAttendees,
      'isRegistered': isRegistered,
      'requiresRegistration': requiresRegistration,
      if (organizer != null) 'organizer': organizer,
    };
  }

  bool get isFull {
    if (maxAttendees == null) return false;
    return currentAttendees >= maxAttendees!;
  }

  bool get isPast => DateTime.now().isAfter(endTime);

  bool get isUpcoming => DateTime.now().isBefore(startTime);

  bool get isOngoing =>
      DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);

  bool get canRegister =>
      requiresRegistration && !isRegistered && !isFull && !isPast;
}
