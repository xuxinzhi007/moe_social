import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:package_info_plus/package_info_plus.dart';

import '../auth_service.dart';
import 'startup_update_preferences.dart';
import 'update_service.dart';

/// 进入主界面后静默检查更新（仅 Android，与登录态无关）。
class StartupUpdateService {
  StartupUpdateService._();

  static const Duration _cooldown = Duration(hours: 24);
  static const Duration _contextRetryDelay = Duration(milliseconds: 400);

  /// 在主界面首帧之后调用；内部吞掉异常，不影响主流程。
  static Future<void> tryLaunchUpdateCheck() async {
    if (kDebugMode) return;
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;

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
      final localCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (!UpdateService.isRemoteNewerThanLocal(
        localVersion: packageInfo.version,
        localVersionCode: localCode,
        remoteVersion: info.version,
        remoteVersionCode: info.versionCode,
      )) {
        return;
      }

      // 强制更新始终提示；软更新尊重「稍后」记录的 versionCode。
      if (!info.forceUpdate) {
        final dismissedCode =
            await StartupUpdatePreferences.getDismissedAutoPromptVersionCode();
        if (dismissedCode != null &&
            info.versionCode > 0 &&
            dismissedCode == info.versionCode) {
          return;
        }
        final dismissedName =
            await StartupUpdatePreferences.getDismissedAutoPromptVersion();
        if (dismissedName == info.version && info.versionCode <= 0) {
          return;
        }
      }

      if (!ctx.mounted) return;
      UpdateService.presentUpdateDialog(
        ctx,
        info,
        onRemindLater: info.forceUpdate
            ? null
            : () {
                unawaited(
                  StartupUpdatePreferences.setDismissedAutoPromptVersion(
                    info.version,
                  ),
                );
                if (info.versionCode > 0) {
                  unawaited(
                    StartupUpdatePreferences.setDismissedAutoPromptVersionCode(
                      info.versionCode,
                    ),
                  );
                }
              },
      );
    } catch (e, st) {
      debugPrint('StartupUpdateService: $e\n$st');
    }
  }
}
