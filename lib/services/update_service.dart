import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// App 内更新服务
/// 支持 GitHub 加速镜像和 App 内下载安装
class UpdateService {
  static const String _owner = 'xuxinzhi007';
  static const String _repo = 'moe_social';
  
  // GitHub 加速镜像列表（按优先级排序）
  static const List<String> _mirrorPrefixes = [
    'https://mirror.ghproxy.com/',      // ghproxy 加速
    'https://gh.ddlc.top/',              // ddlc 加速
    'https://github.moeyy.xyz/',         // moeyy 加速
    '',                                   // 原始地址（最后尝试）
  ];
  
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
      builder: (context) => AlertDialog(
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                children: [
                  Icon(Icons.speed, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    '已启用国内加速下载',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startDownload(context, downloadUrl, fileName, version);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7F7FD5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('立即更新'),
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

  /// 使用加速镜像下载
  static Future<String?> downloadWithMirror(
    String originalUrl,
    String savePath,
    void Function(int received, int total, String mirror) onProgress,
    CancelToken cancelToken,
  ) async {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(minutes: 10);

    for (int i = 0; i < _mirrorPrefixes.length; i++) {
      final mirror = _mirrorPrefixes[i];
      final url = mirror.isEmpty ? originalUrl : '$mirror$originalUrl';
      final mirrorName = mirror.isEmpty ? '原始地址' : _getMirrorName(mirror);
      
      try {
        debugPrint('尝试下载: $url');
        
        await dio.download(
          url,
          savePath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            onProgress(received, total, mirrorName);
          },
          options: Options(
            headers: {
              'User-Agent': 'MoeSocial-App',
            },
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
        
        // 下载成功
        return savePath;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          debugPrint('下载已取消');
          return null;
        }
        debugPrint('镜像 $mirrorName 下载失败: ${e.message}');
        // 继续尝试下一个镜像
        continue;
      } catch (e) {
        debugPrint('镜像 $mirrorName 下载出错: $e');
        continue;
      }
    }
    
    return null; // 所有镜像都失败
  }

  /// 获取镜像名称
  static String _getMirrorName(String mirror) {
    if (mirror.contains('ghproxy')) return 'ghproxy加速';
    if (mirror.contains('ddlc')) return 'ddlc加速';
    if (mirror.contains('moeyy')) return 'moeyy加速';
    return '镜像';
  }

  /// 安装 APK
  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      debugPrint('安装结果: ${result.type} - ${result.message}');
    } catch (e) {
      debugPrint('安装失败: $e');
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
  double _progress = 0;
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
        _status = '正在连接服务器...';
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
            _progress = total > 0 ? received / total : 0;
            _currentMirror = mirror;
            _status = '正在下载... ${_formatBytes(received)} / ${_formatBytes(total)}';
          });
        },
        _cancelToken,
      );

      if (!mounted) return;

      if (result != null) {
        setState(() {
          _isDownloading = false;
          _downloadComplete = true;
          _filePath = result;
          _status = '下载完成！';
          _progress = 1.0;
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
                '${(_progress * 100).toStringAsFixed(1)}%',
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.speed, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _speedText.isEmpty ? '计算中...' : _speedText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.cloud_download, size: 14, color: Colors.green[400]),
                    const SizedBox(width: 4),
                    Text(
                      _currentMirror,
                      style: TextStyle(fontSize: 12, color: Colors.green[600]),
                    ),
                  ],
                ),
              ],
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
            onPressed: () {
              Navigator.pop(context);
              if (_filePath != null) {
                UpdateService.installApk(_filePath!);
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