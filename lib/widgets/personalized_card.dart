import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/user.dart';
import '../providers/device_info_provider.dart';
import '../providers/user_level_provider.dart';
import '../services/weather_service.dart';
import 'avatar_image.dart';
import 'daily_quote_widget.dart';
import 'moe_loading.dart';

class PersonalizedCard extends StatefulWidget {
  const PersonalizedCard({super.key});

  @override
  State<PersonalizedCard> createState() => _PersonalizedCardState();
}

class _PersonalizedCardState extends State<PersonalizedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  User? _user;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_loadUserInfo());
      try {
        final provider = Provider.of<DeviceInfoProvider>(context, listen: false);
        await provider.refreshLocalDeviceContext(
          requestLocationPermission: true,
          includeNetworkAndBattery: false,
        );
      } catch (_) {}
      if (mounted) {
        await _loadWeatherData();
      }
    });
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getUserInfo();
      if (!mounted) {
        return;
      }
      setState(() => _user = user);
      final levelProvider = Provider.of<UserLevelProvider>(context, listen: false);
      if (levelProvider.userLevel == null && user.id.isNotEmpty) {
        unawaited(levelProvider.loadUserLevel(user.id));
      }
    } catch (_) {}
  }

  Future<void> _loadWeatherData() async {
    if (_isLoadingWeather) {
      return;
    }
    setState(() => _isLoadingWeather = true);
    try {
      final provider = Provider.of<DeviceInfoProvider>(context, listen: false);
      if (provider.latitude != null && provider.longitude != null) {
        final weather = await WeatherService.getWeatherByLocation(
          provider.latitude!,
          provider.longitude!,
        );
        if (weather != null) {
          if (mounted) {
            setState(() => _weatherData = weather);
          }
          return;
        }
      }
      final cityName = _getCity(provider);
      final weather = await WeatherService.getWeatherByCity(cityName);
      if (weather != null && mounted) {
        setState(() => _weatherData = weather);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isLoadingWeather = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，还没睡？';
    if (hour < 12) return '早上好，今天也会有好事发生';
    if (hour < 14) return '中午好，记得先照顾好自己';
    if (hour < 18) return '下午好，节奏可以慢一点';
    return '晚上好，适合看看今天的新内容';
  }

  String _getCity(DeviceInfoProvider provider) {
    if (_weatherData != null) {
      return _weatherData!.city;
    }
    final locationText = provider.locationText;
    if (locationText.isEmpty ||
        locationText.contains('失败') ||
        locationText.contains('权限') ||
        locationText.contains('开启')) {
      return '北京';
    }
    final parts = locationText.split(' ');
    for (final part in parts) {
      if (part.contains('市') || part.contains('区') || part.contains('县')) {
        return part.replaceAll(RegExp(r'[市区县]'), '');
      }
    }
    return parts.isNotEmpty ? parts.first : '北京';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceInfoProvider, UserLevelProvider>(
      builder: (context, deviceInfo, levelProvider, _) {
        final size = MediaQuery.sizeOf(context);
        final compact = size.width < 430 || size.height < 760;
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 20,
            compact ? 16 : 18,
            compact ? 18 : 20,
            compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF667EEA),
                Color(0xFF7C63D7),
                Color(0xFFD07BEA),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              _buildAmbientBubble(
                right: -18,
                top: -22,
                size: 92,
                alpha: 0.1,
              ),
              _buildAmbientBubble(
                left: -30,
                bottom: -34,
                size: 126,
                alpha: 0.06,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(deviceInfo, levelProvider, compact: compact),
                  const SizedBox(height: 10),
                  _buildMoodStrip(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmbientBubble({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required double alpha,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = math.sin(_controller.value * 2 * math.pi) * 7;
        final dy = math.cos(_controller.value * 2 * math.pi) * 7;
        return Positioned(
          left: left == null ? null : left + dx,
          right: right == null ? null : right + dx,
          top: top == null ? null : top + dy,
          bottom: bottom == null ? null : bottom + dy,
          child: child!,
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildHeader(
    DeviceInfoProvider deviceInfo,
    UserLevelProvider levelProvider, {
    required bool compact,
  }) {
    final username = (_user?.username ?? '').trim();
    final displayName = username.isEmpty ? '萌友' : username;
    final isVip = _user?.isVip ?? false;
    final level = levelProvider.currentLevel;
    final levelColor = levelProvider.getLevelColor(level);
    final levelTitle = levelProvider.levelTitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 2.4,
            ),
          ),
          child: NetworkAvatarImage(
            imageUrl: _user?.avatar,
            radius: compact ? 22 : 24,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            placeholderIcon: Icons.person_rounded,
            placeholderColor: Colors.white70,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: compact
              ? _buildCompactIdentityBlock(
                  displayName: displayName,
                  isVip: isVip,
                  level: level,
                  levelTitle: levelTitle,
                  levelColor: levelColor,
                )
              : _buildWideIdentityBlock(
                  displayName: displayName,
                  isVip: isVip,
                  level: level,
                  levelTitle: levelTitle,
                  levelColor: levelColor,
                ),
        ),
        const SizedBox(width: 10),
        _buildWeatherCard(deviceInfo, compact: compact),
      ],
    );
  }

  Widget _buildCompactIdentityBlock({
    required String displayName,
    required bool isVip,
    required int level,
    required String levelTitle,
    required Color levelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getGreeting(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isVip) ...[
                _buildVipChip(compact: true),
                const SizedBox(width: 6),
              ],
              _buildLevelChip(level, levelTitle, levelColor, compact: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWideIdentityBlock({
    required String displayName,
    required bool isVip,
    required int level,
    required String levelTitle,
    required Color levelColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getGreeting(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Flexible(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isVip) ...[
                      _buildVipChip(),
                      const SizedBox(width: 8),
                    ],
                    _buildLevelChip(level, levelTitle, levelColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVipChip({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD95E), Color(0xFFFFA63D)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'VIP',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLevelChip(
    int level,
    String levelTitle,
    Color levelColor, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: levelColor.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: compact ? 10 : 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            compact ? 'Lv.$level' : 'Lv.$level · $levelTitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(DeviceInfoProvider provider, {required bool compact}) {
    return GestureDetector(
      onTap: () async {
        try {
          final p = Provider.of<DeviceInfoProvider>(context, listen: false);
          await p.refreshLocalDeviceContext(
            requestLocationPermission: true,
            includeNetworkAndBattery: false,
          );
        } catch (_) {}
        if (mounted) {
          await _loadWeatherData();
        }
      },
      child: Container(
        constraints: BoxConstraints(
          minHeight: compact ? 56 : 64,
          minWidth: compact ? 74 : 92,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 8 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.14),
          ),
        ),
        child: _isLoadingWeather
            ? SizedBox(
                width: compact ? 74 : 92,
                height: compact ? 40 : 48,
                child: Center(
                  child: MoeSmallLoading(color: Colors.white, size: 14),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 34 : 40,
                    height: compact ? 34 : 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _weatherData?.getWeatherEmoji() ?? '⛅',
                        style: TextStyle(fontSize: compact ? 18 : 20),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weatherData != null ? '${_weatherData!.temp}°' : '26°',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 12 : 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: compact ? 1 : 2),
                      Text(
                        _getCity(provider),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontSize: compact ? 9 : 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildMoodStrip() {
    return Container(
      width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 16,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DailyQuoteWidget(
              textColor: Colors.white.withValues(alpha: 0.96),
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}
