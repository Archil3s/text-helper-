import 'contact_item.dart';

class ContactGroup {
  const ContactGroup({
    required this.id,
    required this.name,
    required this.contacts,
  });

  final String id;
  final String name;
  final List<ContactItem> contacts;

  int get contactCount => contacts.length;
}
