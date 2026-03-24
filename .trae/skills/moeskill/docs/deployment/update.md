# 应用内更新功能

## 概述

应用内更新功能允许Moe Social应用在不通过应用商店的情况下更新自身。本指南将详细介绍应用内更新功能的实现方法和最佳实践。

## 功能特点

- **自动检查更新**：应用启动时自动检查是否有新版本
- **后台下载**：在后台下载更新包，不影响用户体验
- **安装提示**：下载完成后提示用户安装更新
- **强制更新**：对于重要更新可以强制用户更新
- **更新进度**：显示更新下载进度

## 技术实现

### 1. 服务器端配置

#### 更新检查接口

创建一个API接口用于检查更新：

```go
// backend/api/internal/handler/user/updatehandler.go
func CheckUpdateHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CheckUpdateRequest
		if err := httpx.Parse(r, &req); err != nil {
			httpx.Error(w, err)
			return
		}

		// 从数据库或配置中获取最新版本信息
		latestVersion, err := svcCtx.VersionModel.GetLatestVersion()
		if err != nil {
			httpx.Error(w, err)
			return
		}

		// 比较版本号
		isUpdateAvailable := compareVersions(req.CurrentVersion, latestVersion.Version) > 0

		resp := types.CheckUpdateResponse{
			HasUpdate:       isUpdateAvailable,
			LatestVersion:   latestVersion.Version,
			UpdateUrl:       latestVersion.DownloadUrl,
			UpdateSize:      latestVersion.Size,
			ReleaseNotes:    latestVersion.ReleaseNotes,
			ForceUpdate:     latestVersion.ForceUpdate,
		}

		httpx.Ok(w, resp)
	}
}
```

#### 版本管理

创建版本管理模型：

```go
// backend/model/version.go
type AppVersion struct {
	ID           uint      `gorm:"primaryKey" json:"id"`
	Version      string    `gorm:"size:20;not null" json:"version"`
	DownloadUrl  string    `gorm:"size:255;not null" json:"download_url"`
	Size         int64     `json:"size"`
	ReleaseNotes string    `gorm:"type:text" json:"release_notes"`
	ForceUpdate  bool      `gorm:"default:false" json:"force_update"`
	CreatedAt    time.Time `json:"created_at"`
}
```

### 2. 客户端实现

#### 更新检查服务

创建更新检查服务：

```dart
// lib/services/update_service.dart
class UpdateService {
  static const String _checkUpdateUrl = 'https://api.moesocial.com/v1/check-update';

  static Future<UpdateInfo?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final response = await http.post(
        Uri.parse(_checkUpdateUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_version': packageInfo.version,
          'platform': Platform.operatingSystem,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['has_update']) {
          return UpdateInfo(
            version: data['latest_version'],
            url: data['update_url'],
            size: data['update_size'],
            releaseNotes: data['release_notes'],
            forceUpdate: data['force_update'],
          );
        }
      }
    } catch (e) {
      print('Error checking update: $e');
    }
    return null;
  }
}

class UpdateInfo {
  final String version;
  final String url;
  final int size;
  final String releaseNotes;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.url,
    required this.size,
    required this.releaseNotes,
    required this.forceUpdate,
  });
}
```

#### 下载服务

创建下载服务：

```dart
// lib/services/update_service.dart (续)
class DownloadService {
  static Future<File?> downloadUpdate(String url, ValueChanged<double>? onProgress) async {
    try {
      final response = await http.Client().send(
        http.Request('GET', Uri.parse(url)),
      );

      final contentLength = response.contentLength;
      var receivedBytes = 0;
      
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/update.apk');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        if (contentLength != null && onProgress != null) {
          final progress = receivedBytes / contentLength;
          onProgress(progress);
        }
        await sink.add(chunk);
      }

      await sink.close();
      return file;
    } catch (e) {
      print('Error downloading update: $e');
      return null;
    }
  }
}
```

#### 安装服务

创建安装服务：

```dart
// lib/services/update_service.dart (续)
class InstallService {
  static Future<bool> installUpdate(File file) async {
    try {
      if (Platform.isAndroid) {
        final result = await Process.run('pm', [
          'install',
          '-r',
          file.path,
        ]);
        return result.exitCode == 0;
      } else if (Platform.isIOS) {
        // iOS不支持应用内安装，需要引导用户到App Store
        return false;
      }
    } catch (e) {
      print('Error installing update: $e');
    }
    return false;
  }
}
```

### 3. 集成到应用

#### 应用启动时检查更新

在应用启动时检查更新：

```dart
// lib/main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 检查更新
  final updateInfo = await UpdateService.checkUpdate();
  if (updateInfo != null) {
    // 处理更新
    _handleUpdate(updateInfo);
  }
  
  runApp(const MyApp());
}

void _handleUpdate(UpdateInfo updateInfo) {
  // 显示更新对话框
  // ...
}
```

#### 更新对话框

创建更新对话框：

```dart
// lib/widgets/update_dialog.dart
class UpdateDialog extends StatelessWidget {
  final UpdateInfo updateInfo;
  final ValueChanged<double>? onProgress;
  
  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    this.onProgress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('发现新版本 ${updateInfo.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(updateInfo.releaseNotes),
          const SizedBox(height: 16),
          Text('更新大小: ${(updateInfo.size / (1024 * 1024)).toStringAsFixed(2)} MB'),
          if (onProgress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: 0,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            const Text('正在下载...'),
          ],
        ],
      ),
      actions: [
        if (!updateInfo.forceUpdate) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后'),
          ),
        ],
        ElevatedButton(
          onPressed: () => _startUpdate(context),
          child: const Text('立即更新'),
        ),
      ],
    );
  }

  void _startUpdate(BuildContext context) async {
    // 开始下载更新
    final file = await DownloadService.downloadUpdate(
      updateInfo.url,
      (progress) {
        if (onProgress != null) {
          onProgress!(progress);
        }
      },
    );

    if (file != null) {
      // 安装更新
      final success = await InstallService.installUpdate(file);
      if (success) {
        // 安装成功
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新安装成功，应用将重启')),
        );
      } else {
        // 安装失败
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('更新安装失败，请手动更新')),
        );
      }
    } else {
      // 下载失败
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('更新下载失败，请检查网络连接')),
      );
    }
  }
}
```

## 平台特定实现

### Android

#### 权限配置

在 `android/app/src/main/AndroidManifest.xml` 中添加权限：

```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

#### 安装实现

在Android平台上，需要使用Intent来安装APK：

```kotlin
// android/app/src/main/kotlin/com/example/moe_social/AutoGLMService.kt
fun installApk(apkPath: String) {
    val file = File(apkPath)
    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        val contentUri = FileProvider.getUriForFile(
            context,
            "com.example.moe_social.provider",
            file
        )
        context.grantUriPermission(
            "com.example.moe_social",
            contentUri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION
        )
        contentUri
    } else {
        Uri.fromFile(file)
    }

    val intent = Intent(Intent.ACTION_VIEW)
    intent.setDataAndType(uri, "application/vnd.android.package-archive")
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    context.startActivity(intent)
}
```

### iOS

iOS不支持应用内安装更新，需要引导用户到App Store：

```dart
// lib/services/update_service.dart
static Future<void> openAppStore() async {
  const url = 'https://apps.apple.com/app/idYOUR_APP_ID';
  if (await canLaunch(url)) {
    await launch(url);
  }
}
```

### Web

Web应用的更新可以通过刷新页面实现：

```dart
// lib/services/update_service.dart
static Future<void> updateWebApp() async {
  // 刷新页面
  html.window.location.reload();
}
```

### 桌面平台

#### Windows

Windows应用可以通过以下方式更新：

1. 下载新的安装包
2. 关闭当前应用
3. 运行新的安装包

#### macOS

macOS应用可以通过以下方式更新：

1. 下载新的DMG文件
2. 提示用户安装
3. 引导用户打开DMG文件

#### Linux

Linux应用可以通过以下方式更新：

1. 下载新的AppImage或DEB/RPM包
2. 提示用户安装
3. 引导用户运行安装命令

## 最佳实践

### 1. 版本管理

- **语义化版本**：使用语义化版本号（如1.0.0）
- **版本比较**：实现可靠的版本比较算法
- **版本控制**：在服务器端管理版本信息

### 2. 下载管理

- **断点续传**：支持断点续传功能
- **网络检测**：在下载前检测网络状态
- **错误处理**：妥善处理下载错误
- **重试机制**：实现下载失败重试机制

### 3. 用户体验

- **后台下载**：在后台下载更新，不影响用户使用
- **进度显示**：显示下载进度，让用户了解更新状态
- **用户选择**：非强制更新时，让用户选择是否更新
- **安装提示**：下载完成后及时提示用户安装

### 4. 安全性

- **签名验证**：验证更新包的签名
- **完整性检查**：检查更新包的完整性
- **来源验证**：确保更新来源可靠
- **权限控制**：只申请必要的权限

### 5. 测试

- **兼容性测试**：测试不同版本的更新
- **网络测试**：测试不同网络环境下的更新
- **错误测试**：测试各种错误场景
- **用户测试**：测试用户体验

## 常见问题

### 1. 下载失败

- **原因**：网络问题、服务器问题、存储空间不足
- **解决方案**：检查网络连接、重试下载、清理存储空间

### 2. 安装失败

- **原因**：权限问题、签名问题、存储空间不足
- **解决方案**：检查权限、验证签名、清理存储空间

### 3. 版本检测失败

- **原因**：网络问题、服务器问题、版本比较算法问题
- **解决方案**：检查网络连接、修复版本比较算法

### 4. 用户体验问题

- **原因**：更新频率过高、强制更新过于频繁、下载速度慢
- **解决方案**：合理控制更新频率、只对重要更新使用强制更新、优化下载速度

## 总结

应用内更新功能为Moe Social应用提供了一种便捷的更新方式，使用户能够及时获取最新版本的功能和修复。通过合理的实现和最佳实践，可以确保更新过程流畅、安全、用户友好。

在实际开发中，应根据目标平台的特性和要求，选择合适的更新策略，并不断优化更新流程，以提升用户体验。