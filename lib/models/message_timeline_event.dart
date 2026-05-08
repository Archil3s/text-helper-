class MessageTimelineEvent {
  const MessageTimelineEvent({
    required this.id,
    required this.reminderId,
    required this.phoneNumber,
    required this.message,
    required this.status,
    required this.title,
    required this.detail,
    required this.createdAt,
  });

  final String id;
  final String? reminderId;
  final String phoneNumber;
  final String message;
  final String status;
  final String title;
  final String detail;
  final DateTime createdAt;

  factory MessageTimelineEvent.fromJson(Map<String, dynamic> json) {
    return MessageTimelineEvent(
      id: json['id'] as String? ?? '',
      reminderId: json['reminderId'] as String?,
      phoneNumber: json['phoneNumber'] as String? ?? '',
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      title: json['title'] as String? ?? 'Timeline event',
      detail: json['detail'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reminderId': reminderId,
      'phoneNumber': phoneNumber,
      'message': message,
      'status': status,
      'title': title,
      'detail': detail,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
