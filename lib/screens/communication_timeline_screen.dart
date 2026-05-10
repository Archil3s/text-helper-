import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";

import "../models/communication_timeline_event.dart";
import "../services/communication_timeline_service.dart";

class CommunicationTimelineScreen extends StatefulWidget {
  const CommunicationTimelineScreen({super.key});

  @override
  State<CommunicationTimelineScreen> createState() =>
      _CommunicationTimelineScreenState();
}

class _CommunicationTimelineScreenState
    extends State<CommunicationTimelineScreen> {
  final _service = CommunicationTimelineService();

  late final List<CommunicationTimelineEvent> _events;

  @override
  void initState() {
    super.initState();

    _events = _service.loadEvents();
  }

  Color _stateColor(CommunicationState state) {
    switch (state) {
      case CommunicationState.delivered:
        return Colors.green;

      case CommunicationState.failed:
        return Colors.red;

      case CommunicationState.pending:
        return Colors.orange;

      case CommunicationState.manual:
        return Colors.blue;

      case CommunicationState.sent:
        return Colors.teal;
    }
  }

  IconData _channelIcon(CommunicationChannel channel) {
    switch (channel) {
      case CommunicationChannel.sms:
        return CupertinoIcons.chat_bubble_text;

      case CommunicationChannel.whatsapp:
        return CupertinoIcons.paperplane_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Communication Timeline",
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Latest Update: unified SMS + WhatsApp communication tracking is now active.",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: Icon(
                      _channelIcon(event.channel),
                    ),
                    title: Text(event.title),
                    subtitle: Text(event.subtitle),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _stateColor(
                          event.state,
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        event.state.name,
                        style: TextStyle(
                          color: _stateColor(event.state),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
