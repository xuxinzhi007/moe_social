/// 单件穿着相对角色中心的摆放。
///
/// - [ox]/[oy]：相对角色宽高的中心偏移（比例）
/// - [scale]：相对角色尺寸
/// - [rot]：旋转角度（度，顺时针为正）
class PetWearLayer {
  const PetWearLayer({
    this.ox = 0,
    this.oy = 0,
    this.scale = 0.5,
    this.rot = 0,
  });

  final double ox;
  final double oy;
  final double scale;
  final double rot;

  PetWearLayer copyWith({
    double? ox,
    double? oy,
    double? scale,
    double? rot,
  }) {
    return PetWearLayer(
      ox: ox ?? this.ox,
      oy: oy ?? this.oy,
      scale: scale ?? this.scale,
      rot: rot ?? this.rot,
    );
  }

  Map<String, dynamic> toJson() => {
        'ox': ox,
        'oy': oy,
        'scale': scale,
        'rot': rot,
      };

  factory PetWearLayer.fromJson(
    Map<String, dynamic>? json,
    PetWearLayer fallback,
  ) {
    if (json == null) return fallback;
    return PetWearLayer(
      ox: (json['ox'] as num?)?.toDouble() ?? fallback.ox,
      oy: (json['oy'] as num?)?.toDouble() ?? fallback.oy,
      scale: (json['scale'] as num?)?.toDouble() ?? fallback.scale,
      rot: (json['rot'] as num?)?.toDouble() ?? fallback.rot,
    );
  }
}

/// 四槽穿着布局（换衣间拖放保存后，小家舞台按此渲染）。
class PetWearLayout {
  const PetWearLayout({
    required this.hat,
    required this.top,
    required this.bottom,
    required this.shoes,
  });

  final PetWearLayer hat;
  final PetWearLayer top;
  final PetWearLayer bottom;
  final PetWearLayer shoes;

  static const defaults = PetWearLayout(
    hat: PetWearLayer(ox: 0, oy: -0.34, scale: 0.4),
    top: PetWearLayer(ox: 0, oy: 0.02, scale: 0.52),
    bottom: PetWearLayer(ox: 0, oy: 0.22, scale: 0.48),
    shoes: PetWearLayer(ox: 0, oy: 0.38, scale: 0.38),
  );

  PetWearLayer slot(String name) => switch (name) {
        'hat' => hat,
        'top' => top,
        'bottom' => bottom,
        'shoes' => shoes,
        _ => const PetWearLayer(),
      };

  PetWearLayout updateSlot(String name, PetWearLayer layer) {
    return PetWearLayout(
      hat: name == 'hat' ? layer : hat,
      top: name == 'top' ? layer : top,
      bottom: name == 'bottom' ? layer : bottom,
      shoes: name == 'shoes' ? layer : shoes,
    );
  }

  Map<String, dynamic> toJson() => {
        'hat': hat.toJson(),
        'top': top.toJson(),
        'bottom': bottom.toJson(),
        'shoes': shoes.toJson(),
      };

  factory PetWearLayout.fromJson(dynamic raw) {
    if (raw is! Map) return defaults;
    final m = Map<String, dynamic>.from(raw);
    return PetWearLayout(
      hat: PetWearLayer.fromJson(
        m['hat'] is Map ? Map<String, dynamic>.from(m['hat'] as Map) : null,
        defaults.hat,
      ),
      top: PetWearLayer.fromJson(
        m['top'] is Map ? Map<String, dynamic>.from(m['top'] as Map) : null,
        defaults.top,
      ),
      bottom: PetWearLayer.fromJson(
        m['bottom'] is Map
            ? Map<String, dynamic>.from(m['bottom'] as Map)
            : null,
        defaults.bottom,
      ),
      shoes: PetWearLayer.fromJson(
        m['shoes'] is Map
            ? Map<String, dynamic>.from(m['shoes'] as Map)
            : null,
        defaults.shoes,
      ),
    );
  }
}
