/// 星辉远征云存档 DTO（对齐 `/api/arena/*`）。
class ArenaOwnedHeroDto {
  const ArenaOwnedHeroDto({
    required this.heroId,
    required this.shards,
    this.bond = 0,
    this.level = 0,
    this.stars = 0,
    this.power = 0,
    this.favorite = 0,
    this.skinId = '',
  });

  final String heroId;
  final int shards;
  final int bond;
  final int level;
  final int stars;
  final int power;
  final int favorite;
  final String skinId;

  factory ArenaOwnedHeroDto.fromJson(Map<String, dynamic> json) {
    return ArenaOwnedHeroDto(
      heroId: (json['hero_id'] ?? '').toString(),
      shards: (json['shards'] as num?)?.toInt() ?? 0,
      bond: (json['bond'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      power: (json['power'] as num?)?.toInt() ?? 0,
      favorite: (json['favorite'] as num?)?.toInt() ?? 0,
      skinId: (json['skin_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'hero_id': heroId,
        'shards': shards,
        'bond': bond,
        'level': level,
        'stars': stars,
        'power': power,
        'favorite': favorite,
        if (skinId.isNotEmpty) 'skin_id': skinId,
      };
}

class ArenaDeckCardDto {
  const ArenaDeckCardDto({
    required this.name,
    required this.description,
    required this.cost,
    required this.icon,
    required this.color,
    required this.damage,
    this.sourceHeroId,
    this.sourceHeroName = '队伍',
    this.targeting = 'single_enemy',
  });

  final String name;
  final String description;
  final int cost;
  final String icon;
  final int color;
  final int damage;
  final String? sourceHeroId;
  final String sourceHeroName;
  final String targeting;

  factory ArenaDeckCardDto.fromJson(Map<String, dynamic> json) {
    return ArenaDeckCardDto(
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      icon: (json['icon'] ?? '✧').toString(),
      color: (json['color'] as num?)?.toInt() ?? 0xFFD47E9B,
      damage: (json['damage'] as num?)?.toInt() ?? 0,
      sourceHeroId: json['source_hero_id']?.toString(),
      sourceHeroName: (json['source_hero_name'] ?? '队伍').toString(),
      targeting: (json['targeting'] ?? 'single_enemy').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'cost': cost,
        'icon': icon,
        'color': color,
        'damage': damage,
        if (sourceHeroId != null && sourceHeroId!.isNotEmpty)
          'source_hero_id': sourceHeroId,
        'source_hero_name': sourceHeroName,
        'targeting': targeting,
      };
}

class ArenaStateDto {
  const ArenaStateDto({
    required this.userId,
    required this.starCrystals,
    required this.towerFloor,
    required this.formationHeroIds,
    required this.ownedHeroes,
    this.deck = const [],
    this.restBuffReady = false,
    this.bondBuffReady = false,
    this.selectedTowerNode = 2,
    this.updatedAt,
  });

  final String userId;
  final int starCrystals;
  final int towerFloor;
  final List<String> formationHeroIds;
  final List<ArenaOwnedHeroDto> ownedHeroes;
  final List<ArenaDeckCardDto> deck;
  final bool restBuffReady;
  final bool bondBuffReady;
  final int selectedTowerNode;
  final String? updatedAt;

  factory ArenaStateDto.fromJson(Map<String, dynamic> json) {
    final formation = <String>[];
    final rawFormation = json['formation_hero_ids'];
    if (rawFormation is List) {
      for (final item in rawFormation) {
        final id = item.toString();
        if (id.isNotEmpty) formation.add(id);
      }
    }
    final owned = <ArenaOwnedHeroDto>[];
    final rawOwned = json['owned_heroes'];
    if (rawOwned is List) {
      for (final item in rawOwned) {
        if (item is Map<String, dynamic>) {
          owned.add(ArenaOwnedHeroDto.fromJson(item));
        } else if (item is Map) {
          owned.add(
            ArenaOwnedHeroDto.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final deck = <ArenaDeckCardDto>[];
    final rawDeck = json['deck'];
    if (rawDeck is List) {
      for (final item in rawDeck) {
        if (item is Map<String, dynamic>) {
          deck.add(ArenaDeckCardDto.fromJson(item));
        } else if (item is Map) {
          deck.add(ArenaDeckCardDto.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ArenaStateDto(
      userId: (json['user_id'] ?? '').toString(),
      starCrystals: (json['star_crystals'] as num?)?.toInt() ?? 0,
      towerFloor: (json['tower_floor'] as num?)?.toInt() ?? 1,
      formationHeroIds: formation,
      ownedHeroes: owned,
      deck: deck,
      restBuffReady: json['rest_buff_ready'] == true,
      bondBuffReady: json['bond_buff_ready'] == true,
      selectedTowerNode: (json['selected_tower_node'] as num?)?.toInt() ?? 2,
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'star_crystals': starCrystals,
        'tower_floor': towerFloor,
        'formation_hero_ids': formationHeroIds,
        'owned_heroes': ownedHeroes.map((e) => e.toJson()).toList(),
        'deck': deck.map((e) => e.toJson()).toList(),
        'rest_buff_ready': restBuffReady,
        'bond_buff_ready': bondBuffReady,
        'selected_tower_node': selectedTowerNode,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

class ArenaSummonPullDto {
  const ArenaSummonPullDto({
    required this.heroId,
    required this.isNew,
    required this.shards,
  });

  final String heroId;
  final bool isNew;
  final int shards;

  factory ArenaSummonPullDto.fromJson(Map<String, dynamic> json) {
    return ArenaSummonPullDto(
      heroId: (json['hero_id'] ?? '').toString(),
      isNew: json['is_new'] == true,
      shards: (json['shards'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArenaSummonResultDto {
  const ArenaSummonResultDto({
    required this.state,
    required this.pulls,
    required this.message,
  });

  final ArenaStateDto state;
  final List<ArenaSummonPullDto> pulls;
  final String message;

  factory ArenaSummonResultDto.fromJson(Map<String, dynamic> json) {
    final pulls = <ArenaSummonPullDto>[];
    final rawPulls = json['pulls'];
    if (rawPulls is List) {
      for (final item in rawPulls) {
        if (item is Map<String, dynamic>) {
          pulls.add(ArenaSummonPullDto.fromJson(item));
        } else if (item is Map) {
          pulls.add(
            ArenaSummonPullDto.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    final rawState = json['state'];
    final stateMap = rawState is Map<String, dynamic>
        ? rawState
        : rawState is Map
            ? Map<String, dynamic>.from(rawState)
            : <String, dynamic>{};
    return ArenaSummonResultDto(
      state: ArenaStateDto.fromJson(stateMap),
      pulls: pulls,
      message: (json['message'] ?? '').toString(),
    );
  }
}

class ArenaClearTowerResultDto {
  const ArenaClearTowerResultDto({
    required this.state,
    required this.crystalReward,
  });

  final ArenaStateDto state;
  final int crystalReward;

  factory ArenaClearTowerResultDto.fromJson(Map<String, dynamic> json) {
    final rawState = json['state'];
    final stateMap = rawState is Map<String, dynamic>
        ? rawState
        : rawState is Map
            ? Map<String, dynamic>.from(rawState)
            : <String, dynamic>{};
    return ArenaClearTowerResultDto(
      state: ArenaStateDto.fromJson(stateMap),
      crystalReward: (json['crystal_reward'] as num?)?.toInt() ?? 0,
    );
  }
}
