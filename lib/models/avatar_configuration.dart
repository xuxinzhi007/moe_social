class AvatarConfiguration {
  final String faceType;
  final String hairStyle;
  final String eyeStyle;
  final String clothesStyle;
  final String accessoryStyle;
  final String hairColor;
  final String skinColor;

  const AvatarConfiguration({
    this.faceType = 'face_1',
    this.hairStyle = 'hair_1',
    this.eyeStyle = 'eyes_1',
    this.clothesStyle = 'clothes_1',
    this.accessoryStyle = 'none',
    this.hairColor = '#8B4513', // 棕色
    this.skinColor = '#FFDBAC', // 肤色
  });

  /// 从JSON创建配置
  factory AvatarConfiguration.fromJson(Map<String, dynamic> json) {
    return AvatarConfiguration(
      faceType: json['face_type'] ?? 'face_1',
      hairStyle: json['hair_style'] ?? 'hair_1',
      eyeStyle: json['eye_style'] ?? 'eyes_1',
      clothesStyle: json['clothes_style'] ?? 'clothes_1',
      accessoryStyle: json['accessory_style'] ?? 'none',
      hairColor: json['hair_color'] ?? '#8B4513',
      skinColor: json['skin_color'] ?? '#FFDBAC',
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'face_type': faceType,
      'hair_style': hairStyle,
      'eye_style': eyeStyle,
      'clothes_style': clothesStyle,
      'accessory_style': accessoryStyle,
      'hair_color': hairColor,
      'skin_color': skinColor,
    };
  }

  /// 创建副本并修改指定字段
  AvatarConfiguration copyWith({
    String? faceType,
    String? hairStyle,
    String? eyeStyle,
    String? clothesStyle,
    String? accessoryStyle,
    String? hairColor,
    String? skinColor,
  }) {
    return AvatarConfiguration(
      faceType: faceType ?? this.faceType,
      hairStyle: hairStyle ?? this.hairStyle,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      clothesStyle: clothesStyle ?? this.clothesStyle,
      accessoryStyle: accessoryStyle ?? this.accessoryStyle,
      hairColor: hairColor ?? this.hairColor,
      skinColor: skinColor ?? this.skinColor,
    );
  }

  /// 获取所有可用的组件选项（动态读取）
  /// 注意：这个方法已被弃用，请使用 AvatarAssetService.instance.getAvailableOptions()
  @Deprecated('Use AvatarAssetService.instance.getAvailableOptions() instead')
  static const Map<String, List<String>> availableOptions = {
    'faces': ['face_1', 'face_2', 'face_3'],
    'hairs': ['hair_1', 'hair_2', 'hair_3', 'hair_4'],
    'eyes': ['eyes_1', 'eyes_2', 'eyes_3'],
    'clothes': ['clothes_1', 'clothes_2', 'clothes_3', 'clothes_4'],
    'accessories': ['none', 'glasses_1', 'glasses_2', 'hat_1'],
  };

  /// 预设的颜色选项
  static const List<String> skinColors = [
    '#FFDBAC', // 浅肤色
    '#F1C27D', // 中等肤色
    '#E0AC69', // 小麦色
    '#C68642', // 深肤色
    '#8D5524', // 深棕色
  ];

  static const List<String> hairColors = [
    '#000000', // 黑色
    '#8B4513', // 棕色
    '#D2691E', // 巧克力色
    '#CD853F', // 沙棕色
    '#FFD700', // 金色
    '#FF6347', // 红色
    '#9370DB', // 紫色
    '#00CED1', // 青色
  ];

  @override
  String toString() {
    return 'AvatarConfiguration(face: $faceType, hair: $hairStyle, eyes: $eyeStyle, clothes: $clothesStyle)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarConfiguration &&
        other.faceType == faceType &&
        other.hairStyle == hairStyle &&
        other.eyeStyle == eyeStyle &&
        other.clothesStyle == clothesStyle &&
        other.accessoryStyle == accessoryStyle &&
        other.hairColor == hairColor &&
        other.skinColor == skinColor;
  }

  @override
  int get hashCode {
    return Object.hash(
      faceType,
      hairStyle,
      eyeStyle,
      clothesStyle,
      accessoryStyle,
      hairColor,
      skinColor,
    );
  }
}