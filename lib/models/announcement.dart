class Announcement {
  final String id;
  final String title;
  final String content;
  final DateTime? publishedAt;

  const Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.publishedAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      publishedAt: DateTime.tryParse(
        json['published_at']?.toString() ??
            json['publishedAt']?.toString() ??
            '',
      ),
    );
  }
}
