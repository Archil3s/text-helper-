import '../models/scheduled_message.dart';
import '../services/local_storage_service.dart';

class ScheduledMessagesRepository {
  ScheduledMessagesRepository({
    LocalStorageService? storage,
  }) : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  Future<List<ScheduledMessage>> loadMessages() async {
    final rawMessages = await _storage.readList(
      LocalStorageService.scheduledMessagesKey,
    );

    if (rawMessages.isEmpty) {
      final seedMessages = _seedMessages;
      await saveMessages(seedMessages);
      return seedMessages;
    }

    return rawMessages.map(ScheduledMessage.fromJson).toList();
  }

  Future<void> saveMessages(List<ScheduledMessage> messages) async {
    await _storage.writeList(
      LocalStorageService.scheduledMessagesKey,
      messages.map((message) => message.toJson()).toList(),
    );
  }

  Future<void> addMessage(ScheduledMessage message) async {
    final messages = await loadMessages();
    await saveMessages([message, ...messages]);
  }

  Future<void> deleteMessage(String id) async {
    final messages = await loadMessages();

    await saveMessages(
      messages.where((message) => message.id != id).toList(),
    );
  }

  Future<void> resetMessages() async {
    await saveMessages(_seedMessages);
  }

  List<ScheduledMessage> get _seedMessages {
    return const [
      ScheduledMessage(
        id: '1',
        groupName: 'Family',
        message: 'Dinner reminder for tonight.',
        scheduledLabel: 'Today • 6:30 PM',
        status: 'Draft',
      ),
      ScheduledMessage(
        id: '2',
        groupName: 'Work',
        message: 'Follow up on the document review.',
        scheduledLabel: 'Tomorrow • 9:00 AM',
        status: 'Queued',
      ),
    ];
  }
}
