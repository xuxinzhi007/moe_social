import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// 应用缓存与本地目录大小；不伪造手机总容量。
class AppStorageService {
  static Future<AppStorageInfo> measureAppStorage() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      final cacheMb = await _directorySizeMb(cacheDir);

      var dataMb = await _directorySizeMb(docsDir);
      try {
        final supportDir = await getApplicationSupportDirectory();
        dataMb += await _directorySizeMb(supportDir);
      } catch (_) {}

      return AppStorageInfo(
        cacheMb: cacheMb,
        dataMb: dataMb,
        measurable: true,
      );
    } catch (_) {
      return const AppStorageInfo(cacheMb: 0, dataMb: 0, measurable: false);
    }
  }

  static Future<double> measureCacheMb() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      return await _directorySizeMb(cacheDir);
    } catch (_) {
      return 0;
    }
  }

  /// 仅清理临时缓存目录，不影响用户数据与登录态。
  static Future<void> clearAppCache() async {
    final cacheDir = await getTemporaryDirectory();
    if (!cacheDir.existsSync()) {
      return;
    }

    for (final entity in cacheDir.listSync()) {
      try {
        if (entity is File) {
          entity.deleteSync();
        } else if (entity is Directory) {
          entity.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// 清理可再生成的本地产物，例如日志数据库和字符卡导出。
  static Future<void> clearGeneratedData() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targets = <FileSystemEntity>[
      File(p.join(docsDir.path, 'autoglm_logs.db')),
      Directory(p.join(docsDir.path, 'character_cards')),
    ];

    for (final entity in targets) {
      try {
        if (entity is File && await entity.exists()) {
          await entity.delete();
        } else if (entity is Directory && await entity.exists()) {
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

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

  static Future<double> _directorySizeMb(Directory directory) async {
    if (!directory.existsSync()) {
      return 0;
    }

    var bytes = 0;
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          bytes += await entity.length();
        } catch (_) {}
      }
    }
    return bytes / (1024 * 1024);
  }
}
