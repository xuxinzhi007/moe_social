import 'dart:convert';

import 'pet_wear.dart';

export 'pet_wear.dart';

/// 养成宠物状态（P0–P4）。
class PetProfile {
  const PetProfile({
    required this.name,
    required this.species,
    required this.hunger,
    required this.energy,
    required this.mood,
    required this.coins,
    required this.ageYears,
    required this.virtue,
    required this.intel,
    required this.sport,
    required this.art,
    required this.labor,
    required this.hatId,
    required this.topId,
    required this.bottomId,
    required this.shoesId,
    required this.sceneId,
    required this.furniture,
    this.roomBoundaries = const [],
    required this.spouseId,
    required this.hasBaby,
    required this.friends,
    this.actorX = 0.5,
    this.actorY = 0.62,
    this.wearLayout = PetWearLayout.defaults,
  });

  final String name;
  final String species;
  final double hunger;
  final double energy;
  final double mood;
  final int coins;
  final int ageYears;
  final int virtue;
  final int intel;
  final int sport;
  final int art;
  final int labor;
  final String hatId;
  final String topId;
  final String bottomId;
  final String shoesId;
  final String sceneId;
  final List<PetFurniture> furniture;

  /// 房间内不可通行的矩形区域，按场景保存，用于墙壁和大型固定结构。
  final List<PetRoomBoundary> roomBoundaries;
  final String spouseId;
  final bool hasBaby;
  final List<String> friends;

  /// 角色在小家内的归一化坐标（可拖动）。
  final double actorX;
  final double actorY;

  /// 换衣间保存的穿着摆放（舞台按此偏移渲染）。
  final PetWearLayout wearLayout;

  PetProfile copyWith({
    String? name,
    double? hunger,
    double? energy,
    double? mood,
    int? coins,
    int? ageYears,
    int? virtue,
    int? intel,
    int? sport,
    int? art,
    int? labor,
    String? hatId,
    String? topId,
    String? bottomId,
    String? shoesId,
    String? sceneId,
    List<PetFurniture>? furniture,
    List<PetRoomBoundary>? roomBoundaries,
    String? spouseId,
    bool? hasBaby,
    List<String>? friends,
    double? actorX,
    double? actorY,
    PetWearLayout? wearLayout,
  }) {
    return PetProfile(
      name: name ?? this.name,
      species: species,
      hunger: hunger ?? this.hunger,
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      coins: coins ?? this.coins,
      ageYears: ageYears ?? this.ageYears,
      virtue: virtue ?? this.virtue,
      intel: intel ?? this.intel,
      sport: sport ?? this.sport,
      art: art ?? this.art,
      labor: labor ?? this.labor,
      hatId: hatId ?? this.hatId,
      topId: topId ?? this.topId,
      bottomId: bottomId ?? this.bottomId,
      shoesId: shoesId ?? this.shoesId,
      sceneId: sceneId ?? this.sceneId,
      furniture: furniture ?? this.furniture,
      roomBoundaries: roomBoundaries ?? this.roomBoundaries,
      spouseId: spouseId ?? this.spouseId,
      hasBaby: hasBaby ?? this.hasBaby,
      friends: friends ?? this.friends,
      actorX: actorX ?? this.actorX,
      actorY: actorY ?? this.actorY,
      wearLayout: wearLayout ?? this.wearLayout,
    );
  }

  /// 云端回写合并：数值用服务器，舞台态（场景/坐标/家具/穿着）保留本地。
  ///
  /// 避免喂食/陪伴把整包 remote 盖上来 → 院子被打回客厅、像「整页重载」。
  PetProfile assimilateCloud(
    PetProfile cloud, {
    bool preferRemoteFurniture = false,
  }) {
    final furn = preferRemoteFurniture && cloud.furniture.isNotEmpty
        ? cloud.furniture
        : (furniture.isNotEmpty ? furniture : cloud.furniture);
    return cloud.copyWith(
      sceneId: sceneId,
      actorX: actorX,
      actorY: actorY,
      furniture: furn,
      roomBoundaries:
          roomBoundaries.isNotEmpty ? roomBoundaries : cloud.roomBoundaries,
      wearLayout: wearLayout,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'species': species,
        'hunger': hunger,
        'energy': energy,
        'mood': mood,
        'coins': coins,
        'age_years': ageYears,
        'virtue': virtue,
        'intel': intel,
        'sport': sport,
        'art': art,
        'labor': labor,
        'hat_id': hatId,
        'top_id': topId,
        'bottom_id': bottomId,
        'shoes_id': shoesId,
        'scene_id': sceneId,
        'furniture': furniture.map((e) => e.toJson()).toList(),
        'room_boundaries': roomBoundaries.map((e) => e.toJson()).toList(),
        'spouse_user_id': spouseId,
        'has_baby': hasBaby,
        'friends': friends,
        'actor_x': actorX,
        'actor_y': actorY,
        'wear_layout': wearLayout.toJson(),
        'outfit_json': jsonEncode(wearLayout.toJson()),
      };

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    final furnRaw = json['furniture_json'] ?? json['furniture'];
    List<PetFurniture> furn = const [];
    if (furnRaw is String && furnRaw.isNotEmpty) {
      final decoded = jsonDecode(furnRaw);
      if (decoded is List) {
        furn = decoded
            .whereType<Map>()
            .map((e) => PetFurniture.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } else if (furnRaw is List) {
      furn = furnRaw
          .whereType<Map>()
          .map((e) => PetFurniture.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    furn = PetFurniture.sanitize(furn);
    final boundariesRaw = json['room_layout_json'] ?? json['room_boundaries'];
    List<PetRoomBoundary> boundaries = const [];
    dynamic decodedBoundaries = boundariesRaw;
    if (decodedBoundaries is String && decodedBoundaries.isNotEmpty) {
      try {
        decodedBoundaries = jsonDecode(decodedBoundaries);
      } catch (_) {
        decodedBoundaries = const [];
      }
    }
    if (decodedBoundaries is List) {
      boundaries = decodedBoundaries
          .whereType<Map>()
          .map((e) => PetRoomBoundary.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    final friendsRaw = json['friends'];
    final friends =
        friendsRaw is List ? friendsRaw.map((e) => '$e').toList() : <String>[];
    dynamic wearRaw = json['wear_layout'] ?? json['outfit_json'];
    if (wearRaw is String && wearRaw.isNotEmpty) {
      try {
        wearRaw = jsonDecode(wearRaw);
      } catch (_) {
        wearRaw = null;
      }
    }
    return PetProfile(
      name: '${json['name'] ?? '小萌'}',
      species: '${json['species'] ?? 'bunny'}',
      hunger: (json['hunger'] as num?)?.toDouble() ?? 80,
      energy: (json['energy'] as num?)?.toDouble() ?? 80,
      mood: (json['mood'] as num?)?.toDouble() ?? 70,
      coins: (json['coins'] as num?)?.toInt() ?? 100,
      ageYears: (json['age_years'] as num?)?.toInt() ?? 1,
      virtue: (json['virtue'] as num?)?.toInt() ?? 12,
      intel: (json['intel'] as num?)?.toInt() ?? 12,
      sport: (json['sport'] as num?)?.toInt() ?? 12,
      art: (json['art'] as num?)?.toInt() ?? 12,
      labor: (json['labor'] as num?)?.toInt() ?? 12,
      hatId: '${json['hat_id'] ?? ''}',
      topId: '${json['top_id'] ?? 'top_basic'}',
      bottomId: '${json['bottom_id'] ?? 'bottom_basic'}',
      shoesId: '${json['shoes_id'] ?? 'shoes_basic'}',
      sceneId: '${json['scene_id'] ?? 'living'}',
      furniture: furn,
      roomBoundaries: PetRoomBoundary.sanitize(boundaries),
      spouseId: '${json['spouse_user_id'] ?? ''}',
      hasBaby: json['has_baby'] == true,
      friends: friends,
      actorX: (json['actor_x'] as num?)?.toDouble() ?? 0.5,
      actorY: (json['actor_y'] as num?)?.toDouble() ?? 0.62,
      wearLayout: PetWearLayout.fromJson(wearRaw),
    );
  }

  static PetProfile fresh() => PetProfile(
        name: '小萌',
        species: 'bunny',
        hunger: 80,
        energy: 80,
        mood: 70,
        coins: 120,
        ageYears: 1,
        virtue: 12,
        intel: 12,
        sport: 12,
        art: 12,
        labor: 12,
        hatId: '',
        topId: 'top_basic',
        bottomId: 'bottom_basic',
        shoesId: 'shoes_basic',
        sceneId: 'living',
        furniture: const [
          PetFurniture(id: 'bed_basic', x: 0.22, y: 0.55, scene: 'living'),
          PetFurniture(id: 'lamp_basic', x: 0.78, y: 0.48, scene: 'living'),
          PetFurniture(id: 'rug_basic', x: 0.5, y: 0.78, scene: 'living'),
        ],
        roomBoundaries: const [],
        spouseId: '',
        hasBaby: false,
        friends: const [],
        actorX: 0.5,
        actorY: 0.64,
        wearLayout: PetWearLayout.defaults,
      );
}

class PetRoomBoundary {
  const PetRoomBoundary({
    required this.id,
    required this.scene,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final String id;
  final String scene;
  final double x;
  final double y;
  final double width;
  final double height;

  PetRoomBoundary copyWith({
    String? scene,
    double? x,
    double? y,
    double? width,
    double? height,
  }) =>
      PetRoomBoundary(
        id: id,
        scene: scene ?? this.scene,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'scene': scene,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory PetRoomBoundary.fromJson(Map<String, dynamic> json) =>
      PetRoomBoundary(
        id: '${json['id'] ?? ''}',
        scene: '${json['scene'] ?? 'living'}',
        x: (json['x'] as num?)?.toDouble() ?? .5,
        y: (json['y'] as num?)?.toDouble() ?? .5,
        width: (json['width'] as num?)?.toDouble() ?? .16,
        height: (json['height'] as num?)?.toDouble() ?? .08,
      );

  static List<PetRoomBoundary> sanitize(List<PetRoomBoundary> values) {
    final ids = <String>{};
    return values
        .where((item) {
          if (item.id.isEmpty || item.scene.isEmpty || ids.contains(item.id))
            return false;
          ids.add(item.id);
          return item.width > 0 && item.height > 0;
        })
        .map((item) => item.copyWith(
              x: item.x.clamp(.04, .96),
              y: item.y.clamp(.12, .94),
              width: item.width.clamp(.03, .9),
              height: item.height.clamp(.03, .8),
            ))
        .toList();
  }
}

class PetFurniture {
  const PetFurniture({
    required this.id,
    required this.x,
    required this.y,
    required this.scene,
    this.rotation = 0,
    this.scale = 1,
  });

  /// 每场景家具上限（防无限刷）。
  static const int maxPerScene = 8;

  /// 同 ID 每场景最多件数。
  static const int maxSameIdPerScene = 2;

  final String id;
  final double x;
  final double y;
  final String scene;

  /// 旋转角度（度，0–359）。
  final int rotation;

  /// 相对尺寸（1 = 默认）。
  final double scale;

  PetFurniture copyWith({
    String? id,
    double? x,
    double? y,
    String? scene,
    int? rotation,
    double? scale,
  }) {
    return PetFurniture(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      scene: scene ?? this.scene,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'scene': scene,
        'rotation': rotation,
        'scale': scale,
      };

  factory PetFurniture.fromJson(Map<String, dynamic> json) {
    var rot = (json['rotation'] as num?)?.toInt() ?? 0;
    rot = ((rot % 360) + 360) % 360;
    final s = (json['scale'] as num?)?.toDouble() ?? 1.0;
    return PetFurniture(
      id: '${json['id'] ?? ''}',
      x: (json['x'] as num?)?.toDouble() ?? 0.5,
      y: (json['y'] as num?)?.toDouble() ?? 0.5,
      scene: '${json['scene'] ?? 'living'}',
      rotation: rot,
      scale: s.clamp(0.35, 2.2),
    );
  }

  /// 清理超量家具（按场景：同 ID 最多 [maxSameIdPerScene]，总数最多 [maxPerScene]）。
  static List<PetFurniture> sanitize(List<PetFurniture> input) {
    final byScene = <String, List<PetFurniture>>{};
    for (final f in input) {
      byScene.putIfAbsent(f.scene, () => []).add(f);
    }
    final out = <PetFurniture>[];
    for (final entry in byScene.entries) {
      final counts = <String, int>{};
      final kept = <PetFurniture>[];
      for (final f in entry.value) {
        final n = counts[f.id] ?? 0;
        if (n >= maxSameIdPerScene) continue;
        if (kept.length >= maxPerScene) break;
        counts[f.id] = n + 1;
        kept.add(f);
      }
      out.addAll(kept);
    }
    return out;
  }
}
