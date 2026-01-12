class Emoji {
  String id;
  String imageUrl;
  List<String> tags;
  bool isAnimated;

  Emoji({
    required this.id,
    required this.imageUrl,
    required this.tags,
    required this.isAnimated,
  });

  factory Emoji.fromJson(Map<String, dynamic> json) {
    return Emoji(
      id: json['id'] ?? '',
      imageUrl: json['image_url'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      isAnimated: json['is_animated'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'tags': tags,
      'is_animated': isAnimated,
    };
  }
}

class EmojiPack {
  String id;
  String name;
  String description;
  String authorName;
  String category;
  double price;
  bool isFree;
  String coverImage;
  List<Emoji> emojis;
  int downloadCount;

  EmojiPack({
    required this.id,
    required this.name,
    required this.description,
    required this.authorName,
    required this.category,
    required this.price,
    required this.isFree,
    required this.coverImage,
    required this.emojis,
    required this.downloadCount,
  });

  factory EmojiPack.fromJson(Map<String, dynamic> json) {
    return EmojiPack(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      authorName: json['author_name'] ?? '',
      category: json['category'] ?? '',
      price: json['price'] ?? 0.0,
      isFree: json['is_free'] ?? false,
      coverImage: json['cover_image'] ?? '',
      emojis: (json['emojis'] as List<dynamic>?)?.map((e) => Emoji.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      downloadCount: json['download_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'author_name': authorName,
      'category': category,
      'price': price,
      'is_free': isFree,
      'cover_image': coverImage,
      'emojis': emojis.map((e) => e.toJson()).toList(),
      'download_count': downloadCount,
    };
  }
}
