import '../models/pet_state.dart';
import 'api_service.dart';

/// 养成域网络层；失败由 Provider 本地回退。
class PetService {
  Future<PetProfile?> fetchState() async {
    try {
      final res = await ApiService.get('/api/pet/state');
      final data = res['data'] ?? res;
      if (data is Map<String, dynamic>) return PetProfile.fromJson(data);
      if (data is Map) {
        return PetProfile.fromJson(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  Future<PetProfile?> feed() => _postProfile('/api/pet/feed');
  Future<PetProfile?> care() => _postProfile('/api/pet/care');

  Future<PetProfile?> setScene(String sceneId) async {
    try {
      final res = await ApiService.post(
        '/api/pet/scene',
        body: {'scene_id': sceneId},
      );
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<PetProfile?> dress({
    String? hat,
    String? top,
    String? bottom,
    String? shoes,
    PetWearLayout? wearLayout,
  }) async {
    try {
      final res = await ApiService.post(
        '/api/pet/dress',
        body: {
          if (hat != null) 'hat_id': hat,
          if (top != null) 'top_id': top,
          if (bottom != null) 'bottom_id': bottom,
          if (shoes != null) 'shoes_id': shoes,
          if (wearLayout != null) 'wear_layout': wearLayout.toJson(),
          if (wearLayout != null) 'outfit_json': wearLayout.toJson(),
        },
      );
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  /// 整表覆盖家具布局 → `pet_profiles.furniture_json`。
  Future<PetProfile?> saveFurniture(List<PetFurniture> slots) async {
    try {
      final res = await ApiService.post(
        '/api/pet/furniture',
        body: {
          'slots': slots
              .map(
                (e) => {
                  'id': e.id,
                  'x': e.x,
                  'y': e.y,
                  'scene': e.scene,
                  'rotation': e.rotation,
                  'scale': e.scale,
                },
              )
              .toList(),
        },
      );
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<({PetProfile? profile, String message})> study(String subject) async {
    try {
      final res = await ApiService.post(
        '/api/pet/study',
        body: {'subject': subject},
      );
      final data = res['data'];
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final p = m['profile'];
        return (
          profile: p is Map
              ? PetProfile.fromJson(Map<String, dynamic>.from(p))
              : null,
          message: '${m['message'] ?? ''}',
        );
      }
    } catch (_) {}
    return (profile: null, message: '');
  }

  Future<({PetProfile? profile, String message})> work() async {
    try {
      final res = await ApiService.post('/api/pet/work', body: {});
      final data = res['data'];
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final p = m['profile'];
        return (
          profile: p is Map
              ? PetProfile.fromJson(Map<String, dynamic>.from(p))
              : null,
          message: '${m['message'] ?? ''}',
        );
      }
    } catch (_) {}
    return (profile: null, message: '');
  }

  Future<PetProfile?> ageUp() => _postProfile('/api/pet/age-up');

  Future<bool> addFriend(String friendId) async {
    try {
      await ApiService.post('/api/pet/friend', body: {'friend_id': friendId});
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<PetProfile?> marry(String spouseId) async {
    try {
      final res = await ApiService.post(
        '/api/pet/marry',
        body: {'spouse_id': spouseId},
      );
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<PetProfile?> baby() => _postProfile('/api/pet/baby');

  Future<({PetProfile? profile, String message, bool win})> adventure() async {
    try {
      final res = await ApiService.post('/api/pet/adventure', body: {});
      final data = res['data'];
      if (data is Map) {
        final m = Map<String, dynamic>.from(data);
        final p = m['profile'];
        return (
          profile: p is Map
              ? PetProfile.fromJson(Map<String, dynamic>.from(p))
              : null,
          message: '${m['message'] ?? ''}',
          win: m['win'] == true,
        );
      }
    } catch (_) {}
    return (profile: null, message: '', win: false);
  }

  Future<PetProfile?> buy(String itemId) async {
    try {
      final res = await ApiService.post(
        '/api/pet/shop/buy',
        body: {'item_id': itemId},
      );
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  Future<PetProfile?> _postProfile(String path) async {
    try {
      final res = await ApiService.post(path, body: {});
      return _profileFrom(res);
    } catch (_) {
      return null;
    }
  }

  PetProfile? _profileFrom(Map<String, dynamic> res) {
    final data = res['data'] ?? res;
    if (data is Map<String, dynamic>) return PetProfile.fromJson(data);
    if (data is Map) {
      return PetProfile.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
}
