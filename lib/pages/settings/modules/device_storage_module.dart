import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../../theme/moe_tokens.dart';
import '../../../services/app_storage_service.dart';
import '../../../providers/device_info_provider.dart';
import '../../../widgets/moe_menu_card.dart';
import '../../../widgets/moe_loading.dart';
import '../../../widgets/moe_toast.dart';
import '../../../widgets/dialogs/confirm_dialog.dart';

class DeviceStorageModule extends StatefulWidget {
  final bool autoUpdateOnLaunch;
  final ValueChanged<bool>? onAutoUpdateChanged;

  const DeviceStorageModule({
    super.key,
    required this.autoUpdateOnLaunch,
    this.onAutoUpdateChanged,
  });

  @override
  State<DeviceStorageModule> createState() => _DeviceStorageModuleState();
}

class _DeviceStorageModuleState extends State<DeviceStorageModule> {
  String _cacheSubtitle = '正在计算…';
  bool _clearingCache = false;
  bool _clearingGeneratedData = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshCacheSubtitle());
  }

  Future<void> _refreshCacheSubtitle() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _cacheSubtitle = '网页版请清理浏览器缓存';
        });
      }
      return;
    }

    final cacheMb = await AppStorageService.measureCacheMb();
    if (!mounted) {
      return;
    }
    setState(() {
      _cacheSubtitle = cacheMb > 0
          ? '当前缓存约 ${AppStorageService.formatMb(cacheMb)}，点击清理'
          : '释放本应用临时文件';
    });
  }

  Future<void> _confirmAndClearCache(BuildContext context) async {
    if (kIsWeb) {
      MoeToast.info(context, '网页版请使用浏览器清理站点数据');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '清理缓存',
      message: '将删除本应用的临时文件，不会影响登录状态与个人数据。',
    );
    if (!ok || !context.mounted) {
      return;
    }

    setState(() => _clearingCache = true);
    try {
      await AppStorageService.clearAppCache();
      if (!context.mounted) {
        return;
      }
      MoeToast.success(context, '缓存已清理');
      await _refreshCacheSubtitle();
    } catch (e) {
      if (context.mounted) {
        MoeToast.error(context, '清理失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  Future<void> _confirmAndClearGeneratedData(BuildContext context) async {
    if (kIsWeb) {
      MoeToast.info(context, '网页版无需清理本地导出文件');
      return;
    }

    final ok = await showConfirmDialog(
      context,
      title: '清理本地数据',
      message: '将删除本地日志和字符卡导出文件，不会影响登录状态。',
    );
    if (!ok || !context.mounted) {
      return;
    }

    setState(() => _clearingGeneratedData = true);
    try {
      await AppStorageService.clearGeneratedData();
      if (!context.mounted) {
        return;
      }
      MoeToast.success(context, '本地数据已清理');
    } catch (e) {
      if (context.mounted) {
        MoeToast.error(context, '清理失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _clearingGeneratedData = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = kIsWeb;

    return MoeMenuCard(
      items: [
        MoeMenuItem(
          icon: Icons.system_security_update_rounded,
          title: '启动时检查更新',
          subtitle: '发现新版本时提醒；无更新不提示。仅 Android 侧载包有效',
          color: MoeTokens.primary,
          onTap: () {},
          trailing: Switch.adaptive(
            value: widget.autoUpdateOnLaunch,
            activeThumbColor: MoeTokens.primary,
            onChanged: widget.onAutoUpdateChanged,
          ),
        ),
        MoeMenuItem(
          icon: Icons.phone_iphone_rounded,
          title: '本机设备信息',
          subtitle: '查看设备ID、系统版本、网络状态等',
          color: Colors.blueGrey,
          onTap: () => _showDeviceInfoSheet(context),
        ),
        if (!isWeb)
          MoeMenuItem(
            icon: Icons.cleaning_services_rounded,
            title: '清理缓存',
            subtitle: _cacheSubtitle,
            color: Colors.amber,
            onTap:
                _clearingCache ? () {} : () => _confirmAndClearCache(context),
            trailing: _clearingCache
                ? const MoeSmallLoading(size: 22)
                : null,
          ),
        if (!isWeb)
          MoeMenuItem(
            icon: Icons.folder_delete_rounded,
            title: '清理本地数据',
            subtitle: '删除日志和字符卡导出等可再生成文件',
            color: Colors.deepOrange,
            onTap: _clearingGeneratedData
                ? () {}
                : () => _confirmAndClearGeneratedData(context),
            trailing: _clearingGeneratedData
                ? const MoeSmallLoading(size: 22)
                : null,
          ),
      ],
    );
  }

  void _showDeviceInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final p = Provider.of<DeviceInfoProvider>(context, listen: false);
          p.refreshLocalDeviceContext(
            requestLocationPermission: true,
            includeNetworkAndBattery: true,
          );
        });
        return Consumer<DeviceInfoProvider>(
          builder: (context, provider, child) {
            final size = MediaQuery.of(context).size;
            final items = <MapEntry<String, String>>[
              MapEntry('设备ID',
                  provider.deviceId.isEmpty ? '未生成' : provider.deviceId),
              MapEntry('设备类型',
                  provider.deviceType.isEmpty ? '未知' : provider.deviceType),
              MapEntry('系统版本',
                  provider.osVersion.isEmpty ? '未知' : provider.osVersion),
              MapEntry('应用版本', provider.versionDisplayLabel),
              MapEntry(
                '屏幕分辨率',
                '${size.width.toStringAsFixed(0)} x ${size.height.toStringAsFixed(0)}',
              ),
              MapEntry('网络状态',
                  provider.networkType.isEmpty ? '未知' : provider.networkType),
              MapEntry('WiFi 名称',
                  provider.wifiName.isEmpty ? '未知' : provider.wifiName),
              MapEntry(
                '电量',
                provider.batteryLevel != null
                    ? '${provider.batteryLevel}%'
                    : '未知',
              ),
              MapEntry(
                '定位',
                () {
                  if (provider.latitude != null && provider.longitude != null) {
                    final coord =
                        '${provider.latitude!.toStringAsFixed(5)}, ${provider.longitude!.toStringAsFixed(5)}';
                    if (provider.locationText.isNotEmpty) {
                      return '${provider.locationText} ($coord)';
                    }
                    return coord;
                  }
                  return '未获取';
                }(),
              ),
            ];

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '本机设备信息',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final e = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: MoeTokens.pageBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  e.key,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: MoeTokens.titleText,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
