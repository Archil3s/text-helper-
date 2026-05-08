class AppointmentReminder {
  const AppointmentReminder({
    required this.id,
    required this.contactId,
    String? contactName,
    required this.phoneNumber,
    required this.appointmentTitle,
    required this.location,
    required this.message,
    required this.scheduledAt,
    required this.isSent,
    required this.recurrenceRule,
    required this.templateName,
    this.sentAt,
    this.notes,
  });

  final String id;
  final String contactId;
  final String phoneNumber;
  final String appointmentTitle;
  final String location;
  final String message;
  final DateTime scheduledAt;
  final bool isSent;
  final String recurrenceRule;
  final String templateName;
  final DateTime? sentAt;
  final String? notes;

  /// Backwards-compatible UI label.
  /// This is NOT persisted and does not store the contact's real name.
  String get contactName => phoneNumber.isEmpty ? 'Contact' : phoneNumber;

  factory AppointmentReminder.fromJson(Map<String, dynamic> json) {
    return AppointmentReminder(
      id: json['id'] as String? ?? '',
      contactId: json['contactId'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      appointmentTitle: json['appointmentTitle'] as String? ?? 'Appointment',
      location: json['location'] as String? ?? '',
      message: json['message'] as String? ?? '',
      scheduledAt: DateTime.tryParse(json['scheduledAt'] as String? ?? '') ??
          DateTime.now(),
      isSent: json['isSent'] as bool? ?? false,
      recurrenceRule: json['recurrenceRule'] as String? ?? 'once',
      templateName: json['templateName'] as String? ?? 'Custom',
      sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'phoneNumber': phoneNumber,
      'appointmentTitle': appointmentTitle,
      'location': location,
      'message': message,
      'scheduledAt': scheduledAt.toIso8601String(),
      'isSent': isSent,
      'recurrenceRule': recurrenceRule,
      'templateName': templateName,
      'sentAt': sentAt?.toIso8601String(),
      'notes': notes,
    };
  }

  AppointmentReminder copyWith({
    String? id,
    String? contactId,
    String? contactName,
    String? phoneNumber,
    String? appointmentTitle,
    String? location,
    String? message,
    DateTime? scheduledAt,
    bool? isSent,
    String? recurrenceRule,
    String? templateName,
    DateTime? sentAt,
    String? notes,
  }) {
    return AppointmentReminder(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      appointmentTitle: appointmentTitle ?? this.appointmentTitle,
      location: location ?? this.location,
      message: message ?? this.message,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isSent: isSent ?? this.isSent,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      templateName: templateName ?? this.templateName,
      sentAt: sentAt ?? this.sentAt,
      notes: notes ?? this.notes,
    );
  }
}
