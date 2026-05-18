class AiLorebook {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiLorebook({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiLorebook.fromMap(Map<String, dynamic> map) => AiLorebook(
        id: map['id'].toString(),
        name: (map['name'] ?? '').toString(),
        description: (map['description'] ?? '').toString(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (map['created_at'] as num).toInt(),
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (map['updated_at'] as num).toInt(),
        ),
      );

  AiLorebook copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiLorebook(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
