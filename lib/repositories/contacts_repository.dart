import '../models/contact_item.dart';
import '../services/local_storage_service.dart';

class ContactsRepository {
  ContactsRepository({
    LocalStorageService? storage,
  }) : _storage = storage ?? LocalStorageService();

  final LocalStorageService _storage;

  Future<List<ContactItem>> loadContacts() async {
    final rawContacts =
        await _storage.readList(LocalStorageService.contactsKey);

    if (rawContacts.isEmpty) {
      final seedContacts = _seedContacts;
      await saveContacts(seedContacts);
      return seedContacts;
    }

    return rawContacts.map(ContactItem.fromJson).toList();
  }

  Future<void> saveContacts(List<ContactItem> contacts) async {
    await _storage.writeList(
      LocalStorageService.contactsKey,
      contacts.map((contact) => contact.toJson()).toList(),
    );
  }

  Future<void> addContact(ContactItem contact) async {
    final contacts = await loadContacts();
    await saveContacts([...contacts, contact]);
  }

  Future<void> deleteContact(String id) async {
    final contacts = await loadContacts();

    await saveContacts(
      contacts.where((contact) => contact.id != id).toList(),
    );
  }

  Future<void> resetContacts() async {
    await saveContacts(_seedContacts);
  }

  List<ContactItem> get _seedContacts {
    return const [
      ContactItem(
        id: '1',
        name: 'Alex Carter',
        phoneNumber: '(555) 010-1001',
        note: 'Primary test recipient',
      ),
      ContactItem(
        id: '2',
        name: 'Morgan Lee',
        phoneNumber: '(555) 010-1002',
        note: 'Family group',
      ),
      ContactItem(
        id: '3',
        name: 'Taylor Brooks',
        phoneNumber: '(555) 010-1003',
        note: 'Work group',
      ),
    ];
  }
}
