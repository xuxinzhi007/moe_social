import '../models/gift.dart';
import 'api_service.dart';

/// 礼物商城目录：唯一数据来源为后端 `/api/gifts`。
class GiftCatalogService {
  GiftCatalogService._();

  static Future<List<Gift>> fetch({
    int page = 1,
    int pageSize = 80,
    String? viewerUserId,
  }) async {
    final rows = await ApiService.getGifts(
      page: page,
      pageSize: pageSize,
      viewerUserId: viewerUserId,
    );
    return rows.map(Gift.fromCatalogApi).toList();
  }

  /// 取价格较低的前 [limit] 个礼物（用于演示动效等场景）。
  static List<Gift> pickPreviewSamples(List<Gift> catalog, {int limit = 6}) {
    if (catalog.isEmpty) return const [];
    final sorted = List<Gift>.from(catalog)
      ..sort((a, b) => a.price.compareTo(b.price));
    return sorted.take(limit).toList();
  }
}
