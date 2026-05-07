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
}
