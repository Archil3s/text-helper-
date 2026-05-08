class SendLogEntry {
  const SendLogEntry({
    required this.id,
    String? contactName,
    required this.phoneNumber,
    required this.message,
    required this.createdAt,
    required this.status,
    this.errorMessage,
    this.reminderId,
  });

  final String id;
  final String phoneNumber;
  final String message;
  final DateTime createdAt;
  final String status;
  final String? errorMessage;
  final String? reminderId;

  /// Backwards-compatible UI label.
  /// This is NOT persisted and does not store the contact's real name.
  String get contactName => phoneNumber.isEmpty ? 'Contact' : phoneNumber;

  factory SendLogEntry.fromJson(Map<String, dynamic> json) {
    return SendLogEntry(
      id: json['id'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'unknown',
      errorMessage: json['errorMessage'] as String?,
      reminderId: json['reminderId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'errorMessage': errorMessage,
      'reminderId': reminderId,
    };
  }
}
