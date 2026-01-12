class BaseConfig {
  String faceShape;
  String skinColor;
  String eyeType;
  String hairStyle;
  String hairColor;

  BaseConfig({
    required this.faceShape,
    required this.skinColor,
    required this.eyeType,
    required this.hairStyle,
    required this.hairColor,
  });

  factory BaseConfig.fromJson(Map<String, dynamic> json) {
    return BaseConfig(
      faceShape: json['face_shape'] ?? '',
      skinColor: json['skin_color'] ?? '',
      eyeType: json['eye_type'] ?? '',
      hairStyle: json['hair_style'] ?? '',
      hairColor: json['hair_color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'face_shape': faceShape,
      'skin_color': skinColor,
      'eye_type': eyeType,
      'hair_style': hairStyle,
      'hair_color': hairColor,
    };
  }
}

class OutfitConfig {
  String clothes;
  List<String> accessories;
  String background;

  OutfitConfig({
    required this.clothes,
    required this.accessories,
    required this.background,
  });

  factory OutfitConfig.fromJson(Map<String, dynamic> json) {
    return OutfitConfig(
      clothes: json['clothes'] ?? '',
      accessories: List<String>.from(json['accessories'] ?? []),
      background: json['background'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'clothes': clothes,
      'accessories': accessories,
      'background': background,
    };
  }
}

class UserAvatar {
  String userId;
  BaseConfig baseConfig;
  OutfitConfig currentOutfit;
  List<String> ownedOutfits;

  UserAvatar({
    required this.userId,
    required this.baseConfig,
    required this.currentOutfit,
    required this.ownedOutfits,
  });

  factory UserAvatar.fromJson(Map<String, dynamic> json) {
    return UserAvatar(
      userId: json['user_id'] ?? '',
      baseConfig: BaseConfig.fromJson(json['base_config'] ?? {}),
      currentOutfit: OutfitConfig.fromJson(json['current_outfit'] ?? {}),
      ownedOutfits: List<String>.from(json['owned_outfits'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'base_config': baseConfig.toJson(),
      'current_outfit': currentOutfit.toJson(),
      'owned_outfits': ownedOutfits,
    };
  }
}

class OutfitPart {
  String id;
  String type;
  String imageUrl;

  OutfitPart({
    required this.id,
    required this.type,
    required this.imageUrl,
  });

  factory OutfitPart.fromJson(Map<String, dynamic> json) {
    return OutfitPart(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      imageUrl: json['image_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'image_url': imageUrl,
    };
  }
}

class AvatarOutfit {
  String id;
  String name;
  String description;
  String category;
  String style;
  double price;
  bool isFree;
  String imageUrl;
  List<OutfitPart> parts;
  String createdAt;

  AvatarOutfit({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.style,
    required this.price,
    required this.isFree,
    required this.imageUrl,
    required this.parts,
    required this.createdAt,
  });

  factory AvatarOutfit.fromJson(Map<String, dynamic> json) {
    return AvatarOutfit(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      style: json['style'] ?? '',
      price: json['price'] ?? 0.0,
      isFree: json['is_free'] ?? false,
      imageUrl: json['image_url'] ?? '',
      parts: (json['parts'] as List<dynamic>?)?.map((e) => OutfitPart.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'style': style,
      'price': price,
      'is_free': isFree,
      'image_url': imageUrl,
      'parts': parts.map((e) => e.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}
