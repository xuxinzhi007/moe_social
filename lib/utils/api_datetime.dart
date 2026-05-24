/// 解析后端返回的时间字符串。
///
/// 后端 GORM 的 `created_at` 多为 UTC，若以 `yyyy-MM-dd HH:mm:ss` 无后缀返回，
/// 需按 UTC 解析再转本地，否则在东八区会固定偏差约 8 小时。
DateTime parseApiDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return DateTime.now();
  }
  final s = raw.trim();
  if (RegExp(r'[zZ]|[+-]\d{2}:?\d{2}$').hasMatch(s)) {
    return DateTime.parse(s).toLocal();
  }
  final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  return DateTime.parse('${normalized}Z').toLocal();
}
