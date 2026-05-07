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

  factory ContactItem.fromJson(Map<String, dynamic> json) {
    return ContactItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'note': note,
    };
  }
}
