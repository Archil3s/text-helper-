enum CommunicationChannel {
  sms,
  whatsapp,
}

enum CommunicationState {
  pending,
  sent,
  delivered,
  failed,
  manual,
}

class CommunicationTimelineEvent {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final CommunicationChannel channel;
  final CommunicationState state;

  const CommunicationTimelineEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.channel,
    required this.state,
  });
}
