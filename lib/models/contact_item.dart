class ContactItem {
  const ContactItem({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.note,
  });

  final String id;
  final String name;
  final String phoneNumber;
  final String? note;
}
