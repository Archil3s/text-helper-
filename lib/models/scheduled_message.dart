class ScheduledMessage {
  const ScheduledMessage({
    required this.id,
    required this.groupName,
    required this.message,
    required this.scheduledLabel,
    required this.status,
  });

  final String id;
  final String groupName;
  final String message;
  final String scheduledLabel;
  final String status;

  factory ScheduledMessage.fromJson(Map<String, dynamic> json) {
    return ScheduledMessage(
      id: json['id'] as String? ?? '',
      groupName: json['groupName'] as String? ?? '',
      message: json['message'] as String? ?? '',
      scheduledLabel: json['scheduledLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'Draft',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupName': groupName,
      'message': message,
      'scheduledLabel': scheduledLabel,
      'status': status,
    };
  }
}
