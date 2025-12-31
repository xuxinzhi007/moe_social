import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateService {
  static const String _owner = 'xuxinzhi007';
  static const String _repo = 'moe_social';
  
  // 检查更新
  static Future<void> checkUpdate(BuildContext context, {bool showNoUpdateToast = false}) async {
    try {
      // 1. 获取当前 App 版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      // 2. 获取 GitHub 最新 Release
      // 使用 /releases 接口获取列表，取第一个，这样兼容 Pre-release 和 Latest
      final url = Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases');
      final response = await http.get(url);

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

        final data = releases.first; // 取最新的一个
        final String tagName = data['tag_name'] ?? ''; // e.g., "v1.0.1"
        final String remoteVersion = tagName.replaceAll('v', ''); // remove 'v' prefix
        final String body = data['body'] ?? '暂无更新日志';
        final List assets = data['assets'] ?? [];
        
        // 寻找 APK 下载链接
        String? downloadUrl;
        for (var asset in assets) {
          final String name = asset['name'] ?? '';
          if (name.endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }
        
        // 如果没找到 APK，就跳 Release 页面
        downloadUrl ??= data['html_url'];

        // 3. 比较版本
        if (_hasNewVersion(currentVersion, remoteVersion)) {
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersion, body, downloadUrl!);
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
            const SnackBar(content: Text('检查更新过于频繁，请稍后再试 (GitHub API 403)')),
          );
        }
      } else if (response.statusCode == 404) {
        if (showNoUpdateToast && context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('仓库不存在或为私有仓库，无法检查更新')),
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

  // 简单的版本比较: return true if remote > local
  static bool _hasNewVersion(String local, String remote) {
    try {
      List<int> localParts = local.split('.').map(int.parse).toList();
      List<int> remoteParts = remote.split('.').map(int.parse).toList();

      for (int i = 0; i < remoteParts.length; i++) {
        if (i >= localParts.length) return true; // remote 1.0.1 > local 1.0
        
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return false; // equal or local is longer (e.g. 1.0.1 > 1.0)
    } catch (e) {
      return false; // parsing failed
    }
  }

  static void _showUpdateDialog(BuildContext context, String version, String note, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('发现新版本 v$version'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('更新内容:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(note),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

