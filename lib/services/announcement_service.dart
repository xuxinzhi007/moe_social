import '../auth_service.dart';
import '../models/announcement.dart';
import 'api_response.dart';
import 'api_service.dart';

class AnnouncementService {
  static Future<List<Announcement>> list({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await ApiService.get(
        '/api/announcements?page=$page&page_size=$pageSize',
      );
      if (!ApiResponse.isSuccess(response)) return [];

      final rows = ApiResponse.listOf(
        response,
        keys: const ['items', 'data'],
      );
      return rows
          .whereType<Map>()
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Announcement?> getById(String id) async {
    if (id.trim().isEmpty) return null;
    try {
      final response = await ApiService.get('/api/announcements/$id');
      if (!ApiResponse.isSuccess(response)) return null;

      final item = ApiResponse.object(
        response,
        keys: const ['item', 'announcement', 'data'],
      );
      if (item.isEmpty) return null;
      return Announcement.fromJson(item);
    } catch (_) {
      return null;
    }
  }

  /// 登录用户拉取最新公告（用于首页横幅等）。
  static Future<Announcement?> latestPublished() async {
    if (!AuthService.isLoggedIn) return null;
    final items = await list(page: 1, pageSize: 1);
    if (items.isEmpty) return null;
    return items.first;
  }
}
