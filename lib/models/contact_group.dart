class ContactGroup {
  const ContactGroup({
    required this.id,
    required this.name,
    required this.contactIds,
    this.isBlockedGroup = false,
  });

  final String id;
  final String name;
  final List<String> contactIds;
  final bool isBlockedGroup;

  factory ContactGroup.fromJson(Map<String, dynamic> json) {
    return ContactGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed group',
      contactIds: (json['contactIds'] as List? ?? <dynamic>[])
          .whereType<String>()
          .toList(),
      isBlockedGroup: json['isBlockedGroup'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactIds': contactIds,
      'isBlockedGroup': isBlockedGroup,
    };
  }

  ContactGroup copyWith({
    String? id,
    String? name,
    List<String>? contactIds,
    bool? isBlockedGroup,
  }) {
    return ContactGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      contactIds: contactIds ?? this.contactIds,
      isBlockedGroup: isBlockedGroup ?? this.isBlockedGroup,
    );
  }
}
