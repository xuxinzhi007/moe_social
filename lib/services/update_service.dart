import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// App 内更新服务
/// 支持 GitHub 加速镜像和 App 内下载安装
class UpdateService {
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

  // 当前下载取消令牌
  static CancelToken? _cancelToken;
  
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
        
        // 寻找 APK 下载链接
        String? downloadUrl;
        String? fileName;
        for (var asset in assets) {
          final String name = asset['name'] ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            fileName = name;
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
    String fileName,
  ) {
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
                  _startDownload(context, downloadUrl, fileName, version);
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
    String version,
  ) async {
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
        const SnackBar(
          content: Text(
            '若系统提示与已安装应用冲突：debug 与 release 签名不同需先卸载；'
            '或新版 versionCode 必须高于当前安装。',
          ),
          duration: Duration(seconds: 6),
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

  const _DownloadProgressDialog({
    required this.originalUrl,
    required this.fileName,
    required this.version,
  });

  @override
  State<_DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  /// null 表示未知总大小（走不确定进度条），0~1 为确定比例。
  double? _progress;
  String _status = '准备下载...';
  String _currentMirror = '';
  String _speedText = '';
  bool _isDownloading = true;
  bool _downloadComplete = false;
  String? _filePath;
  
  // 用于计算下载速度
  int _lastReceived = 0;
  DateTime _lastTime = DateTime.now();
  
  late CancelToken _cancelToken;

  @override
  void initState() {
    super.initState();
    _cancelToken = CancelToken();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      // 获取下载目录
      final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
      final savePath = '${dir.path}/${widget.fileName}';
      
      // 删除旧文件（如果存在）
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      setState(() {
        _status = '正在测速各条下载线路（小流量并行）…';
        _progress = null;
        _currentMirror = '';
      });

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
          
          // 计算下载速度
          final now = DateTime.now();
          final duration = now.difference(_lastTime).inMilliseconds;
          if (duration > 500) { // 每500ms更新一次速度
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
        setState(() {
          _isDownloading = false;
          _downloadComplete = true;
          _filePath = result;
          _status = '下载完成！';
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
              _downloadComplete ? '下载完成' : '正在更新 v${widget.version}',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
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
          
          // 状态信息
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
          
          // 下载速度和镜像信息
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
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                      Icon(Icons.cloud_download, size: 14, color: Colors.green[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _currentMirror,
                          style: TextStyle(fontSize: 12, color: Colors.green[600]),
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
          if (_downloadComplete) ...[
            const SizedBox(height: 12),
            Text(
              '安装失败若提示「与已安装应用冲突」：本地 debug 包与 Release APK 签名不同，需先卸载；'
              '或确认 pubspec 中 + 号后的数字（versionCode）大于已安装版本。',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.35),
            ),
          ],
        ],
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
          ElevatedButton(
            onPressed: () async {
              if (_filePath == null) return;
              final path = _filePath!;
              await UpdateService.installApk(context, path);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
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