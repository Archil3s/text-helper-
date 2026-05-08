class NzSmsRecipient {
  const NzSmsRecipient({
    required this.id,
    required this.name,
    required this.number,
    required this.consented,
    this.note,
    this.isTestNumber = false,
  });

  final String id;
  final String name;
  final String number;
  final bool consented;
  final String? note;
  final bool isTestNumber;

  factory NzSmsRecipient.fromJson(Map<String, dynamic> json) {
    return NzSmsRecipient(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      number: json['number'] as String? ?? '',
      consented: json['consented'] as bool? ?? false,
      note: json['note'] as String?,
      isTestNumber: json['isTestNumber'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'number': number,
      'consented': consented,
      'note': note,
      'isTestNumber': isTestNumber,
    };
  }

  NzSmsRecipient copyWith({
    String? id,
    String? name,
    String? number,
    bool? consented,
    String? note,
    bool? isTestNumber,
  }) {
    return NzSmsRecipient(
      id: id ?? this.id,
      name: name ?? this.name,
      number: number ?? this.number,
      consented: consented ?? this.consented,
      note: note ?? this.note,
      isTestNumber: isTestNumber ?? this.isTestNumber,
    );
  }
}
