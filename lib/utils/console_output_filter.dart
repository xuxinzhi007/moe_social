bool shouldSuppressConsoleLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) return true;

  if (_keepPatterns.any((pattern) => pattern.hasMatch(trimmed))) {
    return false;
  }

  return _noisePrefixes.any((prefix) => trimmed.startsWith(prefix)) ||
      _noiseContains.any((needle) => trimmed.contains(needle));
}

const List<String> _noisePrefixes = [
  '🔍',
  '✅',
  '📍',
  '📱',
  '💡',
  '🚀',
  '🧭',
  '🔐',
  '🌐',
  '📋',
  '📊',
];

const List<String> _noiseContains = [
  '调试',
  '成功',
  '最终',
  '尝试',
  '解析成功',
  '加载成功',
  '刷新成功',
  '获取成功',
  '检查',
  '状态更新',
  '静默',
  'Web 调试',
];

final List<RegExp> _keepPatterns = [
  RegExp(r'(error|exception|failed|fail|warn|warning)', caseSensitive: false),
  RegExp(r'(错误|异常|失败|堆栈|重试失败|请求超时|网络连接错误|客户端连接错误|未知请求错误|HTTP错误|API错误)',
      caseSensitive: false),
  RegExp(r'^[❌⚠️]'),
];
