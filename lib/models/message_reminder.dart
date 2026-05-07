class MessageReminder {
  const MessageReminder({
    required this.id,
    required this.title,
    required this.messagePreview,
    required this.reminderTime,
    required this.status,
  });

  final String id;
  final String title;
  final String messagePreview;
  final String reminderTime;
  final String status;
}
