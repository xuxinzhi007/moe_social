/// 本应用可测量的存储占用（缓存 + 本地数据目录）。
class AppStorageInfo {
  const AppStorageInfo({
    required this.cacheMb,
    required this.dataMb,
    required this.measurable,
  });

  final double cacheMb;
  final double dataMb;

  /// 能否通过 path_provider 可靠测量（Web 等平台为 false）。
  final bool measurable;

  double get totalAppMb => cacheMb + dataMb;
}

/// 非 IO 平台不暴露真实文件系统，统一返回不可测量状态。
class AppStorageService {
  static Future<AppStorageInfo> measureAppStorage() async {
    return const AppStorageInfo(cacheMb: 0, dataMb: 0, measurable: false);
  }

  static Future<double> measureCacheMb() async => 0;

  static Future<void> clearAppCache() async {}

  static Future<void> clearGeneratedData() async {}

  static String formatMb(double mb) {
    if (mb < 0.05) {
      return '几乎为空';
    }
    if (mb < 1024) {
      final digits = mb < 10 ? 1 : 0;
      return '${mb.toStringAsFixed(digits)} MB';
    }
    return '${(mb / 1024).toStringAsFixed(1)} GB';
  }
}
