import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/user.dart';
import '../providers/device_info_provider.dart';
import '../providers/main_nav_controller.dart';
import '../providers/user_level_provider.dart';
import '../services/weather_service.dart';
import '../theme/moe_tokens.dart';
import 'avatar_image.dart';
import 'moe_loading.dart';

/// 首页顶部轻条：问候 + 身份 + 天气。
///
/// 刻意做成一行（对标朋友圈/IG 克制顶栏），不做半屏仪表盘。
class PersonalizedCard extends StatefulWidget {
  const PersonalizedCard({super.key});

  @override
  State<PersonalizedCard> createState() => _PersonalizedCardState();
}

class _PersonalizedCardState extends State<PersonalizedCard> {
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUserProfileNotifier.value;
    AuthService.currentUserProfileNotifier.addListener(_onUserProfileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_loadUserInfo());
      try {
        final provider =
            Provider.of<DeviceInfoProvider>(context, listen: false);
        await provider.refreshLocalDeviceContext(
          requestLocationPermission: true,
          includeNetworkAndBattery: false,
        );
      } catch (_) {}
      if (mounted) await _loadWeatherData();
    });
  }

  void _onUserProfileChanged() {
    if (!mounted) return;
    setState(() {
      _user = AuthService.currentUserProfileNotifier.value;
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getUserInfo();
      if (!mounted) return;
      final levelProvider =
          Provider.of<UserLevelProvider>(context, listen: false);
      if (levelProvider.userLevel == null && user.id.isNotEmpty) {
        unawaited(levelProvider.loadUserLevel(user.id));
      }
    } catch (_) {}
  }

  Future<void> _loadWeatherData() async {
    if (_isLoadingWeather) return;
    setState(() => _isLoadingWeather = true);
    try {
      final provider = Provider.of<DeviceInfoProvider>(context, listen: false);
      final lat = provider.latitude;
      final lon = provider.longitude;
      if (lat != null && lon != null) {
        final weather = await WeatherService.getWeatherByLocation(lat, lon);
        if (weather != null && mounted) {
          setState(() => _weatherData = weather);
        }
        return;
      }
      final city = _knownCity(provider);
      if (city == null) return;
      final weather = await WeatherService.getWeatherByCity(city);
      if (weather != null && mounted) {
        setState(() => _weatherData = weather);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  @override
  void dispose() {
    AuthService.currentUserProfileNotifier
        .removeListener(_onUserProfileChanged);
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  /// 只有定位文案里真有城市时才返回，拿不到就返回 null，不再默认北京。
  String? _knownCity(DeviceInfoProvider provider) {
    final locationText = provider.locationText.trim();
    if (locationText.isEmpty ||
        locationText.contains('失败') ||
        locationText.contains('权限') ||
        locationText.contains('开启') ||
        locationText.startsWith('当前位置')) {
      return null;
    }
    final parts = locationText.split(' ');
    for (final part in parts) {
      if (part.contains('市') || part.contains('区') || part.contains('县')) {
        final city = part.replaceAll(RegExp(r'[市区县]'), '');
        if (city.isNotEmpty) return city;
      }
    }
    final first = parts.isEmpty ? '' : parts.first.trim();
    return first.isEmpty ? null : first;
  }

  String _cityLabel(DeviceInfoProvider provider) {
    final fromWeather = _weatherData?.city.trim() ?? '';
    if (fromWeather.isNotEmpty) return fromWeather;
    return _knownCity(provider) ?? '定位';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceInfoProvider, UserLevelProvider>(
      builder: (context, deviceInfo, levelProvider, _) {
        final username = (_user?.username ?? '').trim();
        final displayName = username.isEmpty ? '萌友' : username;
        final isVip = _user?.isVip ?? false;
        final level = levelProvider.currentLevel;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.read<MainNavController>().requestTab(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MoeTokens.surface1,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MoeTokens.surfaceBorder),
              ),
              child: Row(
                children: [
                  NetworkAvatarImage(
                    key: ValueKey(_user?.avatar),
                    imageUrl: _user?.avatar,
                    radius: 18,
                    backgroundColor: MoeTokens.surface0,
                    placeholderIcon: Icons.person_rounded,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_greeting()}，$displayName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MoeTokens.titleText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (isVip) 'VIP',
                            'Lv.$level',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _WeatherChip(
                    loading: _isLoadingWeather,
                    emoji: _weatherData?.getWeatherEmoji() ?? '⛅',
                    temp:
                        _weatherData != null ? '${_weatherData!.temp}°' : '--',
                    city: _cityLabel(deviceInfo),
                    onTap: () async {
                      try {
                        await deviceInfo.refreshLocalDeviceContext(
                          requestLocationPermission: true,
                          includeNetworkAndBattery: false,
                        );
                      } catch (_) {}
                      if (mounted) await _loadWeatherData();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({
    required this.loading,
    required this.emoji,
    required this.temp,
    required this.city,
    required this.onTap,
  });

  final bool loading;
  final String emoji;
  final String temp;
  final String city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: MoeTokens.surface0,
          borderRadius: BorderRadius.circular(12),
        ),
        child: loading
            ? const SizedBox(
                width: 48,
                height: 20,
                child: Center(child: MoeSmallLoading(size: 14)),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    temp,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: MoeTokens.titleText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 48),
                    child: Text(
                      city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
