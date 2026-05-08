class SmsTemplate {
  const SmsTemplate({
    required this.id,
    required this.name,
    required this.body,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String body;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isBuiltIn;

  factory SmsTemplate.fromJson(Map<String, dynamic> json) {
    return SmsTemplate(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed template',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'Custom',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'body': body,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isBuiltIn': isBuiltIn,
    };
  }

  SmsTemplate copyWith({
    String? id,
    String? name,
    String? body,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isBuiltIn,
  }) {
    return SmsTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      body: body ?? this.body,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }
}
