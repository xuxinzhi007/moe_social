import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// 与已安装应用对比 APK 签名的结果（仅 Android 原生通道有效）。
class ApkSignatureCompareResult {
  ApkSignatureCompareResult({
    required this.match,
    this.skippedPlatform = false,
    this.errorCode,
    this.message,
    this.installedSha256,
    this.apkSha256,
    this.apkPackage,
    this.installedPackage,
  });

  final bool match;
  /// 非 Android，未做检测，按原流程安装。
  final bool skippedPlatform;
  final String? errorCode;
  final String? message;
  final String? installedSha256;
  final String? apkSha256;
  final String? apkPackage;
  final String? installedPackage;

  bool get canInstallInPlace => skippedPlatform || match;

  factory ApkSignatureCompareResult.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) {
      return ApkSignatureCompareResult(match: false, errorCode: 'null_response');
    }
    return ApkSignatureCompareResult(
      match: raw['match'] == true,
      errorCode: raw['error'] as String?,
      message: raw['message'] as String?,
      installedSha256: raw['installedSha256'] as String?,
      apkSha256: raw['apkSha256'] as String?,
      apkPackage: raw['apkPackage'] as String?,
      installedPackage: raw['installedPackage'] as String?,
    );
  }
}

/// App 内更新服务
/// 支持 GitHub 加速镜像和 App 内下载安装
class UpdateService {
  static const MethodChannel _androidUpdateChannel =
      MethodChannel('com.moe_social/app_update');

  static const String _owner = 'xuxinzhi007';
  static const String _repo = 'moe_social';
  
  /// GitHub Release 直链前加前缀，由镜像代为拉取。公益镜像会随时限流、变慢或失效，故多备几条并支持「卡住则换线」。
  /// 格式均为：`前缀 + 完整 https://github.com/...`（与多数 ghproxy 类服务文档一致）。
  static const List<String> _mirrorPrefixes = [
    'https://ghfast.top/',
    'https://mirror.ghproxy.com/',
    'https://ghproxy.net/',
    'https://github.moeyy.xyz/',
    'https://gh.ddlc.top/',
    '', // 直连（有代理或国际网络时可能更快）
  ];

  /// 单条线路若超过此时长没有任何新字节，则放弃并试下一条（避免「能连但极慢」一直耗在第一条上）。
  static const Duration _stallGiveUp = Duration(seconds: 55);

  /// 测速：最多拉取的字节数（Range 请求；若服务端忽略 Range 则读到上限后主动断开）。
  static const int _probeMaxBytes = 256 * 1024;

  /// 测速：整条线路最长等待时间。
  static const Duration _probeMaxDuration = Duration(seconds: 12);

  /// 测速：至少收到这么多字节才认为线路可用。
  static const int _probeMinBytes = 2048;

  /// 认为 APK 有效的最小体积（避免缓存/HTML 错误页被当成安装包）。
  static const int _apkMinBytes = 64 * 1024;

  // 当前下载取消令牌
  static CancelToken? _cancelToken;

  /// 生成稳定、安全的本地文件名（含版本便于卸载后辨认）。
  static String _safeApkFileName(String versionLabel, String originalFileName) {
    final base = p.basename(originalFileName);
    final safe =
        base.replaceAll(RegExp(r'[^A-Za-z0-9\.\-_+()]'), '_').replaceAll('__', '_');
    final v = versionLabel.replaceAll(RegExp(r'[^0-9A-Za-z\.\+]'), '_');
    return 'MoeSocial_v${v}_$safe';
  }

  /// 优先保存到系统「下载/MoeSocial」目录（卸载应用后仍可保留）；不可用时退回应用专属目录。
  static Future<String> resolveApkSavePath({
    required String versionLabel,
    required String originalFileName,
  }) async {
    final name = _safeApkFileName(versionLabel, originalFileName);
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.path.isNotEmpty) {
        final dir = Directory(p.join(downloads.path, 'MoeSocial'));
        await dir.create(recursive: true);
        return p.join(dir.path, name);
      }
    } catch (e) {
      debugPrint('使用系统下载目录失败，改用应用目录: $e');
    }
    final fallback =
        await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final sub = Directory(p.join(fallback.path, 'updates'));
    await sub.create(recursive: true);
    return p.join(sub.path, name);
  }

  /// 校验下载是否完整且像 ZIP/APK（APK 实为 ZIP，文件头 PK\x03\x04）。
  static Future<bool> validateDownloadedApk(
    String path,
    int? expectedContentLength,
  ) async {
    final f = File(path);
    if (!await f.exists()) {
      return false;
    }
    final len = await f.length();
    if (len < _apkMinBytes) {
      debugPrint('UpdateService: APK 过小 ($len)，可能未下完或是错误页');
      return false;
    }
    if (expectedContentLength != null &&
        expectedContentLength > 0 &&
        len != expectedContentLength) {
      debugPrint(
        'UpdateService: 大小不符 本地=$len 预期=$expectedContentLength',
      );
      return false;
    }
    RandomAccessFile? raf;
    try {
      raf = await f.open(mode: FileMode.read);
      final h = await raf.read(4);
      if (h.length < 4) {
        return false;
      }
      if (h[0] != 0x50 || h[1] != 0x4B || h[2] != 0x03 || h[3] != 0x04) {
        debugPrint('UpdateService: 不是有效的 ZIP/APK 文件头');
        return false;
      }
    } catch (e) {
      debugPrint('UpdateService: 读取文件头失败 $e');
      return false;
    } finally {
      await raf?.close();
    }
    return true;
  }

  /// 人类可读：保存位置说明（用于 UI）。
  static String humanReadableSaveHint(String fullPath) {
    final lower = fullPath.toLowerCase();
    if (lower.contains('moesocial') &&
        (lower.contains('/download/') || lower.contains('\\download\\'))) {
      return '已保存到系统「下载 → MoeSocial」文件夹，卸载本应用后仍可在此找到安装包。';
    }
    return '已保存到应用目录；卸载本应用后此文件可能被系统删除，建议立即安装或点「分享」另存。';
  }
  
  /// 检查更新
  static Future<void> checkUpdate(BuildContext context, {bool showNoUpdateToast = false}) async {
    try {
      // 1. 获取当前 App 版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. 获取 GitHub 最新 Release
      final url = Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases');
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'MoeSocial-App',
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final List releases = jsonDecode(response.body);
        if (releases.isEmpty) {
          if (showNoUpdateToast && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未发现任何发布版本')),
            );
          }
          return;
        }

        final data = releases.first;
        final String tagName = data['tag_name'] ?? '';
        final String remoteVersion = tagName.replaceAll('v', '');
        final String body = data['body'] ?? '暂无更新日志';
        final List assets = data['assets'] ?? [];
        
        // 寻找 APK 下载链接（GitHub assets[].size 为字节数，用于校验本地已下载包是否完整）
        String? downloadUrl;
        String? fileName;
        int? apkAssetSize;
        for (var asset in assets) {
          final String name = asset['name'] ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            fileName = name;
            final rawSize = asset['size'];
            if (rawSize is int) {
              apkAssetSize = rawSize;
            } else if (rawSize != null) {
              apkAssetSize = int.tryParse(rawSize.toString());
            }
            break;
          }
        }

        // 3. 比较版本
        if (_hasNewVersion(currentVersion, remoteVersion)) {
          if (context.mounted && downloadUrl != null) {
            _showUpdateDialog(
              context,
              remoteVersion,
              body,
              downloadUrl,
              fileName ?? 'app-release.apk',
              expectedAssetBytes: apkAssetSize,
            );
          }
        } else {
          if (showNoUpdateToast && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('当前已是最新版本')),
            );
          }
        }
      } else if (response.statusCode == 403) {
        if (showNoUpdateToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('检查更新过于频繁，请稍后再试')),
          );
        }
      } else if (response.statusCode == 404) {
        if (showNoUpdateToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仓库不存在或为私有仓库')),
          );
        }
      } else {
        if (showNoUpdateToast && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('检查更新失败: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (showNoUpdateToast && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查更新出错: $e')),
        );
      }
    }
  }

  /// 版本比较
  static bool _hasNewVersion(String local, String remote) {
    try {
      List<int> localParts = local.split('.').map(int.parse).toList();
      List<int> remoteParts = remote.split('.').map(int.parse).toList();

      for (int i = 0; i < remoteParts.length; i++) {
        if (i >= localParts.length) return true;
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 对比 [apkPath] 与当前已安装应用的签名（仅 Android）。
  static Future<ApkSignatureCompareResult> compareApkSignatureWithInstalled(
    String apkPath,
  ) async {
    if (!Platform.isAndroid) {
      return ApkSignatureCompareResult(match: true, skippedPlatform: true);
    }
    try {
      final dynamic raw = await _androidUpdateChannel.invokeMethod<dynamic>(
        'compareApkSignatureWithInstalled',
        <String, dynamic>{'apkPath': apkPath},
      );
      if (raw is Map) {
        return ApkSignatureCompareResult.fromMap(
          Map<dynamic, dynamic>.from(raw),
        );
      }
      return ApkSignatureCompareResult(match: false, errorCode: 'bad_response');
    } on PlatformException catch (e) {
      return ApkSignatureCompareResult(
        match: false,
        errorCode: e.code.toLowerCase(),
        message: e.message,
      );
    } catch (e) {
      return ApkSignatureCompareResult(
        match: false,
        errorCode: 'unknown',
        message: '$e',
      );
    }
  }

  /// 打开系统卸载当前应用的界面（用户必须在系统对话框中确认；无法静默卸载）。
  static Future<void> requestUninstallCurrentApp() async {
    if (!Platform.isAndroid) return;
    await _androidUpdateChannel.invokeMethod<void>('requestUninstallCurrentApp');
  }

  /// App 内安装：先比对签名；不一致时引导卸载（无法自动卸载后自动安装）。
  static Future<void> runAndroidInAppInstallWithSignatureCheck(
    BuildContext context,
    String apkPath,
    VoidCallback closeDownloadDialog,
  ) async {
    if (!Platform.isAndroid) {
      await installApk(context, apkPath);
      closeDownloadDialog();
      return;
    }

    final r = await compareApkSignatureWithInstalled(apkPath);
    if (!context.mounted) return;

    if (r.skippedPlatform || r.match) {
      await installApk(context, apkPath);
      closeDownloadDialog();
      return;
    }

    if (r.errorCode == 'package_name_mismatch') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('安装包不匹配'),
          content: Text(
            'APK 包名与当前应用不一致，无法安装。\n'
            '当前：${r.installedPackage ?? "?"}\n'
            'APK：${r.apkPackage ?? "?"}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    if (r.errorCode == 'signing_mismatch') {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('签名不一致'),
          content: const SingleChildScrollView(
            child: Text(
              '新安装包与当前应用的签名不同（例如当前是调试版、新包是正式版），'
              'Android 不允许直接覆盖安装。\n\n'
              '系统不允许应用在后台静默卸载，也不能在卸载后由本应用自动完成安装，'
              '需要你在系统界面确认卸载，再到「下载 → MoeSocial」打开已保存的 APK 安装。',
              style: TextStyle(height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'try'),
              child: const Text('仍尝试安装'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'uninstall'),
              child: const Text('打开卸载界面'),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      if (choice == 'uninstall') {
        await requestUninstallCurrentApp();
        closeDownloadDialog();
        return;
      }
      if (choice == 'try') {
        await installApk(context, apkPath);
        closeDownloadDialog();
      }
      return;
    }

    final tryAnyway = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('无法确认签名'),
        content: Text(
          '签名检测未成功（${r.errorCode ?? "未知"}），无法判断能否覆盖安装。\n'
          '可尝试直接安装，或改用「浏览器下载」。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('尝试安装'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (tryAnyway == true) {
      await installApk(context, apkPath);
      closeDownloadDialog();
    }
  }

  /// 在系统浏览器中打开 APK 直链（由系统/浏览器负责下载）。
  static Future<void> openApkUrlInBrowser(
    BuildContext context,
    String downloadUrl,
  ) async {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载地址无效')),
        );
      }
      return;
    }
    try {
      var ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开浏览器，请手动复制 Release 链接下载')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开浏览器失败: $e')),
        );
      }
    }
  }

  /// 显示更新对话框
  static void _showUpdateDialog(
    BuildContext context,
    String version,
    String note,
    String downloadUrl,
    String fileName, {
    int? expectedAssetBytes,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7F7FD5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.system_update,
                color: Color(0xFF7F7FD5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '发现新版本 v$version',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kDebugMode) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    '当前是调试版（debug 签名）。GitHub 上的 APK 多为正式签名，'
                    '不能直接覆盖安装，需先卸载再装；与「是否下载完整」无关。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.article_outlined, size: 16, color: Colors.grey),
                        SizedBox(width: 6),
                        Text(
                          '更新内容',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.speed, size: 14, color: Colors.green[600]),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'App 内下载会测速选线；也可使用浏览器由系统下载管理器拉取',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '选择下载方式',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _startDownload(
                    context,
                    downloadUrl,
                    fileName,
                    version,
                    expectedAssetBytes: expectedAssetBytes,
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text('App 内下载'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7F7FD5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await openApkUrlInBrowser(context, downloadUrl);
                },
                icon: const Icon(Icons.open_in_browser_rounded, size: 20),
                label: const Text('浏览器下载'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7F7FD5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF7F7FD5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('稍后更新'),
          ),
        ],
      ),
    );
  }

  /// 开始下载
  static Future<void> _startDownload(
    BuildContext context,
    String originalUrl,
    String fileName,
    String version, {
    int? expectedAssetBytes,
  }) async {
    // 检查安装权限（Android）
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要安装权限才能更新应用')),
          );
        }
        return;
      }
    }

    // 显示下载进度对话框
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _DownloadProgressDialog(
          originalUrl: originalUrl,
          fileName: fileName,
          version: version,
          expectedAssetBytes: expectedAssetBytes,
        ),
      );
    }
  }

  /// 并行对各镜像做短测速（小流量），按吞吐量排序；全部失败时退回默认顺序。
  static Future<List<String>> rankMirrorPrefixes(
    String originalUrl, {
    CancelToken? userCancelToken,
  }) async {
    if (userCancelToken?.isCancelled == true) {
      return List<String>.from(_mirrorPrefixes);
    }

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 8,
      headers: <String, dynamic>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 MoeSocial-App',
        'Accept': '*/*',
      },
    ));

    Future<({int index, String prefix, double speed})> probeOne(
        int index, String prefix,) async {
      if (userCancelToken?.isCancelled == true) {
        return (index: index, prefix: prefix, speed: -1.0);
      }
      final url = prefix.isEmpty ? originalUrl : '$prefix$originalUrl';
      final speed =
          await _probeThroughputForUrl(dio, url, userCancelToken: userCancelToken);
      return (index: index, prefix: prefix, speed: speed);
    }

    final futures = <Future<({int index, String prefix, double speed})>>[];
    for (var i = 0; i < _mirrorPrefixes.length; i++) {
      futures.add(probeOne(i, _mirrorPrefixes[i]));
    }
    final results = await Future.wait(futures);

    final allFailed = results.every((e) => e.speed < 0);
    if (allFailed) {
      debugPrint('测速：全部线路不可用，使用默认顺序');
      return List<String>.from(_mirrorPrefixes);
    }

    results.sort((a, b) {
      final as = a.speed < 0 ? -1.0 : a.speed;
      final bs = b.speed < 0 ? -1.0 : b.speed;
      final c = bs.compareTo(as);
      if (c != 0) return c;
      return a.index.compareTo(b.index);
    });
    if (kDebugMode) {
      for (final e in results) {
        final label = mirrorLabelForPrefix(e.prefix);
        if (e.speed >= 0) {
          debugPrint(
            '测速 $label: ${(e.speed / 1024).toStringAsFixed(1)} KB/s',
          );
        } else {
          debugPrint('测速 $label: 不可用');
        }
      }
    }
    return results.map((e) => e.prefix).toList();
  }

  /// 返回字节/秒；失败返回 -1。
  static Future<double> _probeThroughputForUrl(
    Dio dio,
    String url, {
    CancelToken? userCancelToken,
  }) async {
    final probeToken = CancelToken();
    var received = 0;
    final sw = Stopwatch()..start();

    final userPoll = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (userCancelToken?.isCancelled == true && !probeToken.isCancelled) {
        probeToken.cancel('用户取消');
      }
    });

    try {
      final resp = await dio.get<ResponseBody>(
        url,
        cancelToken: probeToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          headers: <String, dynamic>{
            'Range': 'bytes=0-${_probeMaxBytes - 1}',
          },
          validateStatus: (code) =>
              code != null && (code == 200 || code == 206),
        ),
      );

      final body = resp.data;
      if (body == null) {
        return -1;
      }

      try {
        await for (final chunk in body.stream) {
          received += chunk.length;
          if (received >= _probeMaxBytes || sw.elapsed >= _probeMaxDuration) {
            if (!probeToken.isCancelled) {
              probeToken.cancel('测速结束');
            }
            break;
          }
        }
      } on DioException catch (e) {
        if (!CancelToken.isCancel(e)) {
          rethrow;
        }
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        return -1;
      }
    } catch (_) {
      return -1;
    } finally {
      userPoll.cancel();
    }

    if (received < _probeMinBytes) {
      return -1;
    }
    final sec = sw.elapsedMilliseconds / 1000.0;
    if (sec < 0.05) {
      return -1;
    }
    return received / sec;
  }

  /// 使用加速镜像下载（顺序尝试；卡住或失败则换线）。用户取消通过 [userCancelToken] 传递。
  /// [mirrorOrder] 为测速后的线路顺序；为 null 时使用 [_mirrorPrefixes]。
  static Future<String?> downloadWithMirror(
    String originalUrl,
    String savePath,
    void Function(int received, int total, String mirror) onProgress,
    CancelToken userCancelToken, {
    List<String>? mirrorOrder,
  }) async {
    final order = (mirrorOrder != null && mirrorOrder.isNotEmpty)
        ? mirrorOrder
        : _mirrorPrefixes;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(minutes: 45),
      followRedirects: true,
      maxRedirects: 8,
      headers: <String, dynamic>{
        // 部分镜像对非浏览器 UA 限流；保留可识别后缀便于排错
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 MoeSocial-App',
        'Accept': '*/*',
      },
    ));

    for (int i = 0; i < order.length; i++) {
      if (userCancelToken.isCancelled) {
        return null;
      }

      final mirror = order[i];
      final url = mirror.isEmpty ? originalUrl : '$mirror$originalUrl';
      final mirrorName = mirror.isEmpty ? '直连 GitHub' : _getMirrorName(mirror);

      final attemptToken = CancelToken();
      Timer? userBridge;
      Timer? stallWatch;

      void disposeTimers() {
        userBridge?.cancel();
        stallWatch?.cancel();
      }

      void armStallWatch() {
        stallWatch?.cancel();
        stallWatch = Timer(_stallGiveUp, () {
          if (!attemptToken.isCancelled) {
            attemptToken.cancel('线路长时间无进度，尝试下一条');
          }
        });
      }

      userBridge = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (userCancelToken.isCancelled && !attemptToken.isCancelled) {
          attemptToken.cancel('用户取消下载');
        }
      });

      try {
        debugPrint('尝试下载: $url');

        armStallWatch();
        await dio.download(
          url,
          savePath,
          cancelToken: attemptToken,
          onReceiveProgress: (received, total) {
            armStallWatch();
            onProgress(received, total, mirrorName);
          },
          deleteOnError: true,
        );

        disposeTimers();
        return savePath;
      } on DioException catch (e) {
        disposeTimers();
        if (CancelToken.isCancel(e)) {
          if (userCancelToken.isCancelled) {
            debugPrint('下载已取消');
            return null;
          }
          debugPrint('镜像 $mirrorName 中断（将换线）: ${e.error}');
          continue;
        }
        debugPrint('镜像 $mirrorName 下载失败: ${e.message}');
        continue;
      } catch (e) {
        disposeTimers();
        debugPrint('镜像 $mirrorName 下载出错: $e');
        continue;
      }
    }

    return null;
  }

  /// 获取镜像名称
  static String _getMirrorName(String mirror) {
    if (mirror.contains('ghfast')) return 'ghfast';
    if (mirror.contains('ghproxy')) return 'ghproxy';
    if (mirror.contains('ddlc')) return 'ddlc';
    if (mirror.contains('moeyy')) return 'moeyy';
    return '镜像';
  }

  /// 测速/界面展示用线路名
  static String mirrorLabelForPrefix(String prefix) =>
      prefix.isEmpty ? '直连 GitHub' : _getMirrorName(prefix);

  /// 唤起系统 APK 安装界面。
  ///
  /// **常见失败原因（与 applicationId 无关时多半是签名）：**
  /// - 本机是 `flutter run` 的 **debug 包**，Release APK 使用 **release.jks** 签名，二者不能覆盖安装，系统会提示与已安装应用冲突/签名不一致。
  /// - 新 APK 的 **versionCode**（pubspec 里 `+` 后数字）**≤** 已安装版本，也无法覆盖。
  /// - 解决：卸载当前 App 后再装；或始终用同一套签名打升级包。
  static Future<void> installApk(BuildContext context, String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      debugPrint('安装结果: ${result.type} - ${result.message}');
      if (!context.mounted) return;

      if (result.type != ResultType.done) {
        final msg = switch (result.type) {
          ResultType.fileNotFound => '未找到安装包文件',
          ResultType.permissionDenied => '无法打开安装包，请检查存储/安装权限',
          ResultType.noAppToOpen => '没有可用的安装程序',
          ResultType.error => '无法打开安装包：${result.message}',
          ResultType.done => '',
        };
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: const Text(
            '已唤起安装。若失败：① debug/正式签名不同需先卸载；② 新版 versionCode 须更高；'
            '③ 可到「下载 → MoeSocial」手动点 APK。点右侧可复制完整路径。',
          ),
          action: SnackBarAction(
            label: '复制路径',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: filePath));
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('安装失败: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('安装调用异常: $e')),
        );
      }
    }
  }

  /// 取消下载
  static void cancelDownload() {
    _cancelToken?.cancel('用户取消下载');
    _cancelToken = null;
  }
}

/// 下载进度对话框
class _DownloadProgressDialog extends StatefulWidget {
  final String originalUrl;
  final String fileName;
  final String version;
  /// GitHub Release 资源声明的大小（字节），用于与本地已存在文件比对。
  final int? expectedAssetBytes;

  const _DownloadProgressDialog({
    required this.originalUrl,
    required this.fileName,
    required this.version,
    this.expectedAssetBytes,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  /// null 表示未知总大小（走不确定进度条），0~1 为确定比例。
  double? _progress;
  String _status = '正在检查本地安装包…';
  String _currentMirror = '';
  String _speedText = '';
  bool _isDownloading = true;
  bool _downloadComplete = false;
  String? _filePath;
  /// 本地文件复用（未重新走网络下载）。
  bool _reusedLocal = false;
  /// 服务端声明的 Content-Length（若已知），用于校验是否下完。
  int? _expectedTotalBytes;

  // 用于计算下载速度
  int _lastReceived = 0;
  DateTime _lastTime = DateTime.now();

  late CancelToken _cancelToken;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _bootstrap();
  }

  /// 若目标路径已有同版本 APK 且校验通过则直接展示「使用已下载」；否则删损坏包后下载。
  Future<void> _bootstrap() async {
    try {
      final savePath = await UpdateService.resolveApkSavePath(
        versionLabel: widget.version,
        originalFileName: widget.fileName,
      );
      if (!mounted) return;
      final existing = File(savePath);
      if (await existing.exists()) {
        if (!mounted) return;
        final ok = await UpdateService.validateDownloadedApk(
          savePath,
          widget.expectedAssetBytes,
        );
        if (ok && mounted) {
          setState(() {
            _isDownloading = false;
            _downloadComplete = true;
            _reusedLocal = true;
            _filePath = savePath;
            _status = '本地已有本版本安装包，大小与 ZIP 头校验通过，可直接安装';
            _progress = 1;
          });
          return;
        }
        if (!mounted) return;
        try {
          await existing.delete();
        } catch (_) {}
      }
      if (!mounted) return;
      await _runFreshDownload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _status = '检查本地文件出错: $e';
      });
    }
  }

  Future<void> _onRedownloadPressed() async {
    if (!_downloadComplete || _isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadComplete = false;
      _filePath = null;
      _reusedLocal = false;
      _progress = null;
      _status = '正在准备重新下载…';
    });
    final savePath = await UpdateService.resolveApkSavePath(
      versionLabel: widget.version,
      originalFileName: widget.fileName,
    );
    try {
      final f = File(savePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    if (!mounted) return;
    await _runFreshDownload();
  }

  Future<void> _runFreshDownload() async {
    if (!mounted) return;
    _cancelToken = CancelToken();
    setState(() {
      _isDownloading = true;
      _downloadComplete = false;
      _filePath = null;
      _reusedLocal = false;
      _progress = null;
      _expectedTotalBytes = null;
      _currentMirror = '';
      _speedText = '';
      _status = '正在测速各条下载线路（小流量并行）…';
    });

    try {
      final savePath = await UpdateService.resolveApkSavePath(
        versionLabel: widget.version,
        originalFileName: widget.fileName,
      );

      final ranked = await UpdateService.rankMirrorPrefixes(
        widget.originalUrl,
        userCancelToken: _cancelToken,
      );

      if (!mounted || _cancelToken.isCancelled) {
        return;
      }

      final top =
          ranked.isEmpty ? '' : UpdateService.mirrorLabelForPrefix(ranked.first);
      setState(() {
        _status =
            top.isEmpty ? '开始下载…' : '测速完成，优先使用「$top」，开始下载…';
        _lastReceived = 0;
        _lastTime = DateTime.now();
        _speedText = '';
      });

      final result = await UpdateService.downloadWithMirror(
        widget.originalUrl,
        savePath,
        (received, total, mirror) {
          if (!mounted) return;

          if (total > 0) {
            _expectedTotalBytes = total;
          }

          final now = DateTime.now();
          final duration = now.difference(_lastTime).inMilliseconds;
          if (duration > 500) {
            final speed = (received - _lastReceived) / (duration / 1000);
            _lastReceived = received;
            _lastTime = now;
            _speedText = _formatSpeed(speed);
          }

          setState(() {
            _progress = total > 0 ? received / total : null;
            _currentMirror = mirror;
            if (total > 0) {
              _status =
                  '正在下载... ${_formatBytes(received)} / ${_formatBytes(total)}';
            } else {
              _status = '正在下载... 已接收 ${_formatBytes(received)}（总大小未知）';
            }
          });
        },
        _cancelToken,
        mirrorOrder: ranked,
      );

      if (!mounted) return;

      if (result != null) {
        final ok = await UpdateService.validateDownloadedApk(
          result,
          _expectedTotalBytes,
        );
        if (!ok) {
          try {
            await File(result).delete();
          } catch (_) {}
          setState(() {
            _isDownloading = false;
            _downloadComplete = false;
            _filePath = null;
            _status = '安装包校验未通过（可能未下完或是网页错误页），请重试或改用浏览器下载';
            _progress = null;
          });
          return;
        }

        setState(() {
          _isDownloading = false;
          _downloadComplete = true;
          _filePath = result;
          _status = '下载完成并已校验';
          _progress = 1;
        });
      } else {
        setState(() {
          _isDownloading = false;
          _status = '下载失败，请重试';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _status = '下载出错: $e';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 0) return '?';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B/s';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          if (_isDownloading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_downloadComplete)
            const Icon(Icons.check_circle, color: Colors.green, size: 24)
          else
            const Icon(Icons.error, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _downloadComplete
                  ? (_reusedLocal ? '使用已下载的安装包' : '下载完成')
                  : '正在更新 v${widget.version}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _downloadComplete ? Colors.green : const Color(0xFF7F7FD5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Text(
                  _progress != null
                      ? '${(_progress! * 100).toStringAsFixed(1)}%'
                      : '—',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7F7FD5),
                  ),
                ),
              ],
            ),
            if (_isDownloading && _currentMirror.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.speed, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _speedText.isEmpty ? '计算中...' : _speedText,
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[500]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.cloud_download,
                            size: 14, color: Colors.green[400]),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _currentMirror,
                            style: TextStyle(
                                fontSize: 12, color: Colors.green[600]),
                            textAlign: TextAlign.end,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            if (_downloadComplete && _filePath != null) ...[
              const SizedBox(height: 12),
              Text(
                UpdateService.humanReadableSaveHint(_filePath!),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _filePath!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _filePath!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制完整路径')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('复制路径'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Share.shareXFiles(
                          [XFile(_filePath!)],
                          subject: 'Moe Social 更新包',
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('分享 / 另存'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '安装失败若提示「与已安装应用冲突」：debug 与 Release 签名不同需先卸载；'
                '或新版 versionCode（pubspec + 后数字）须高于已安装。',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[600], height: 1.35),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isDownloading)
          TextButton(
            onPressed: () {
              _cancelToken.cancel('用户取消');
              Navigator.pop(context);
            },
            child: const Text('取消'),
          )
        else if (_downloadComplete) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后安装'),
          ),
          TextButton(
            onPressed: () => _onRedownloadPressed(),
            child: const Text('重新下载'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_filePath == null) return;
              final path = _filePath!;
              await UpdateService.runAndroidInAppInstallWithSignatureCheck(
                context,
                path,
                () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('立即安装'),
          ),
        ]
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}