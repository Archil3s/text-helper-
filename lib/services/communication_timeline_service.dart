import "../models/communication_timeline_event.dart";

class CommunicationTimelineService {
  List<CommunicationTimelineEvent> loadEvents() {
    return [
      CommunicationTimelineEvent(
        id: "1",
        title: "SMS Sent",
        subtitle: "Campaign reminder delivered",
        timestamp: DateTime.now().subtract(
          const Duration(minutes: 3),
        ),
        channel: CommunicationChannel.sms,
        state: CommunicationState.delivered,
      ),
      CommunicationTimelineEvent(
        id: "2",
        title: "WhatsApp Handoff",
        subtitle: "Manual handoff opened",
        timestamp: DateTime.now().subtract(
          const Duration(minutes: 1),
        ),
        channel: CommunicationChannel.whatsapp,
        state: CommunicationState.manual,
      ),
    ];
  }
}
