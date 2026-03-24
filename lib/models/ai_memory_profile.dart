class AiMemoryProfile {
  final String id;
  final String agentId;
  final String profileType;
  final String title;
  final String summary;
  final double confidence;
  final DateTime updatedAt;

  const AiMemoryProfile({
    required this.id,
    required this.agentId,
    required this.profileType,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'agent_id': agentId,
        'profile_type': profileType,
        'title': title,
        'summary': summary,
        'confidence': confidence,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AiMemoryProfile.fromMap(Map<String, dynamic> map) {
    return AiMemoryProfile(
      id: map['id'] as String,
      agentId: map['agent_id'] as String,
      profileType: (map['profile_type'] as String?) ?? 'general',
      title: (map['title'] as String?) ?? '',
      summary: (map['summary'] as String?) ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.6,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        map['updated_at'] as int,
      ),
    );
  }
}
