import '../services/api_service.dart';

/// 将相对路径或「旧隧道」下的本站图片 URL 解析为当前 [ApiService.baseUrl] 下可访问的地址。
///
/// - [data:]、不含 `/api/images/` 的外链保持原样
/// - `http(s)://任意主机/api/images/...` 会丢弃原 host，改用当前 API base（修复历史 cpolar 数据）
/// - `/api/images/...` 或裸 key `123_name__file.png` 与 base 拼接
String resolveMediaUrl(
  String? stored, {
  String? apiBaseUrl,
}) {
  final base = (apiBaseUrl ?? ApiService.baseUrl).trim();
  if (stored == null || stored.isEmpty) return '';
  final s = stored.trim();
  if (s.startsWith('data:')) return s;

  final uri = Uri.tryParse(s);
  if (uri != null &&
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https')) {
    if (uri.path.contains('/api/images/')) {
      var path = uri.path;
      if (uri.hasQuery) {
        path = '$path?${uri.query}';
      }
      return _joinBaseAndRef(base, path);
    }
    return s;
  }

  if (s.startsWith('/api/images/')) {
    return _joinBaseAndRef(base, s);
  }

  if (s.contains('__') &&
      !s.contains('://') &&
      !s.startsWith('/') &&
      !s.startsWith('data:')) {
    return _joinBaseAndRef(base, '/api/images/$s');
  }

  return s;
}

String _joinBaseAndRef(String base, String ref) {
  if (base.isEmpty) return ref.startsWith('/') ? ref : '/$ref';
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final u = Uri.parse(b);
  final r = ref.startsWith('/') ? ref.substring(1) : ref;
  return u.resolve(r).toString();
}
