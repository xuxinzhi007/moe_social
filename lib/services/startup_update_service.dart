import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';

import '../auth_service.dart';
import 'startup_update_preferences.dart';
import 'update_service.dart';

/// 冷启动后静默检查更新（仅 Android，与登录态无关）。
class StartupUpdateService {
  StartupUpdateService._();

  static const Duration _cooldown = Duration(hours: 24);
  static const Duration _contextRetryDelay = Duration(milliseconds: 400);

  /// 在首帧之后延迟调用；内部吞掉异常，不影响主流程。
  static Future<void> tryLaunchUpdateCheck() async {
    if (kIsWeb) return;
    if (!Platform.isAndroid) return;

    try {
      if (!await StartupUpdatePreferences.getAutoCheckOnLaunch()) return;

      final last = await StartupUpdatePreferences.getLastAutoCheckTime();
      if (last != null && DateTime.now().difference(last) < _cooldown) {
        return;
      }

      var ctx = AuthService.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) {
        await Future<void>.delayed(_contextRetryDelay);
        ctx = AuthService.navigatorKey.currentContext;
      }
      if (ctx == null || !ctx.mounted) return;

      final result = await UpdateService.fetchLatestRelease();
      await StartupUpdatePreferences.setLastAutoCheckTime(DateTime.now());

      if (result.status != UpdateFetchStatus.ok || result.info == null) return;

      final info = result.info!;
      if (info.downloadUrl == null || info.downloadUrl!.isEmpty) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final current = packageInfo.version;
      if (!UpdateService.isRemoteNewerThanLocal(current, info.version)) return;

      final dismissed =
          await StartupUpdatePreferences.getDismissedAutoPromptVersion();
      if (dismissed == info.version) return;

      if (!ctx.mounted) return;
      UpdateService.presentUpdateDialog(
        ctx,
        info,
        onRemindLater: () {
          unawaited(
            StartupUpdatePreferences.setDismissedAutoPromptVersion(
              info.version,
            ),
          );
        },
      );
    } catch (e, st) {
      debugPrint('StartupUpdateService: $e\n$st');
    }
  }
}
