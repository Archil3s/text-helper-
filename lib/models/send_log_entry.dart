class SendLogEntry {
  const SendLogEntry({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    required this.message,
    required this.createdAt,
    required this.status,
    this.errorMessage,
    this.reminderId,
  });

  final String id;
  final String contactName;
  final String phoneNumber;
  final String message;
  final DateTime createdAt;
  final String status;
  final String? errorMessage;
  final String? reminderId;

  factory SendLogEntry.fromJson(Map<String, dynamic> json) {
    return SendLogEntry(
      id: json['id'] as String? ?? '',
      contactName: json['contactName'] as String? ?? 'Unknown',
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
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'errorMessage': errorMessage,
      'reminderId': reminderId,
    };
  }
}
