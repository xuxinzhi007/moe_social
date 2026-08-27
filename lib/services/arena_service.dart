import '../models/arena_state.dart';
import 'api_service.dart';

/// 星辉远征域网络层；失败由 ViewModel 本地回退。
class ArenaService {
  Future<ArenaStateDto?> fetchState() async {
    try {
      final res = await ApiService.get('/api/arena/state');
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaStateDto?> setFormation(List<String> heroIds) async {
    try {
      final res = await ApiService.put(
        '/api/arena/formation',
        body: {'hero_ids': heroIds},
      );
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaStateDto?> saveDeck(List<ArenaDeckCardDto> cards) async {
    try {
      final res = await ApiService.put(
        '/api/arena/deck',
        body: {'cards': cards.map((e) => e.toJson()).toList()},
      );
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaSummonResultDto?> summon(int count) async {
    try {
      final res = await ApiService.post(
        '/api/arena/summon',
        body: {'count': count},
      );
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic>) {
        return ArenaSummonResultDto.fromJson(data);
      }
      if (data is Map) {
        return ArenaSummonResultDto.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  Future<ArenaStateDto?> homeGift(String heroId) async {
    try {
      final res = await ApiService.post(
        '/api/arena/home/gift',
        body: {'hero_id': heroId},
      );
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaStateDto?> homeTrain() async {
    try {
      final res = await ApiService.post('/api/arena/home/train');
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaStateDto?> saveMeta({
    int? selectedTowerNode,
    bool clearBuffs = false,
  }) async {
    try {
      final res = await ApiService.put(
        '/api/arena/meta',
        body: {
          if (selectedTowerNode != null)
            'selected_tower_node': selectedTowerNode,
          'clear_buffs': clearBuffs,
        },
      );
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaStateDto?> saveSkin({
    required String heroId,
    required String skinId,
  }) async {
    try {
      final res = await ApiService.put(
        '/api/arena/skin',
        body: {'hero_id': heroId, 'skin_id': skinId},
      );
      return _stateFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<ArenaClearTowerResultDto?> clearTower({
    required bool won,
    String? bonusHeroId,
    List<ArenaDeckCardDto>? deck,
  }) async {
    try {
      final res = await ApiService.post(
        '/api/arena/tower/clear',
        body: {
          'won': won,
          if (bonusHeroId != null && bonusHeroId.isNotEmpty)
            'bonus_hero_id': bonusHeroId,
          if (deck != null) 'deck': deck.map((e) => e.toJson()).toList(),
        },
      );
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic>) {
        return ArenaClearTowerResultDto.fromJson(data);
      }
      if (data is Map) {
        return ArenaClearTowerResultDto.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
    } catch (_) {}
    return null;
  }

  ArenaStateDto? _stateFrom(Map<String, dynamic> res) {
    final data = res['data'] ?? res;
    if (data is Map<String, dynamic>) return ArenaStateDto.fromJson(data);
    if (data is Map) {
      return ArenaStateDto.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
