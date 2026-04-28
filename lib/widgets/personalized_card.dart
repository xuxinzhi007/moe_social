import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:async';
import 'daily_quote_widget.dart';
import '../auth_service.dart';
import '../models/user.dart';
import '../providers/device_info_provider.dart';
import '../providers/user_level_provider.dart';
import 'avatar_image.dart';
import 'moe_loading.dart';
import '../services/weather_service.dart';

class PersonalizedCard extends StatefulWidget {
  const PersonalizedCard({super.key});

  @override
  State<PersonalizedCard> createState() => _PersonalizedCardState();
}

class _PersonalizedCardState extends State<PersonalizedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
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

  Future<void> _loadUserInfo() async {
    try {
      final user = await AuthService.getUserInfo();
      if (!mounted) return;
      setState(() => _user = user);
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
      final provider =
          Provider.of<DeviceInfoProvider>(context, listen: false);
      if (provider.latitude != null && provider.longitude != null) {
        final weather = await WeatherService.getWeatherByLocation(
          provider.latitude!,
          provider.longitude!,
        );
        if (weather != null) {
          if (mounted) setState(() => _weatherData = weather);
          return;
        }
      }
      final cityName = _getCity(provider);
      final weather = await WeatherService.getWeatherByCity(cityName);
      if (weather != null && mounted) setState(() => _weatherData = weather);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingWeather = false);
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
    if (hour < 12) return '早上好 ☀️';
    if (hour < 14) return '中午好 🍱';
    if (hour < 18) return '下午好 ☕';
    return '晚上好 🌙';
  }

  String _getCity(DeviceInfoProvider provider) {
    if (_weatherData != null) return _weatherData!.city;
    final locationText = provider.locationText;
    if (locationText.isEmpty ||
        locationText.contains('失败') ||
        locationText.contains('权限') ||
        locationText.contains('开启')) {
      return '北京';
    }
    final parts = locationText.split(' ');
    for (final part in parts) {
      if (part.contains('市') ||
          part.contains('区') ||
          part.contains('县')) {
        return part.replaceAll(RegExp(r'[市区县]'), '');
      }
    }
    return parts.isNotEmpty ? parts.first : '北京';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceInfoProvider, UserLevelProvider>(
      builder: (context, deviceInfo, levelProvider, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667eea).withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // Decorative animated circles
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Positioned(
                  right: -20 + math.sin(_controller.value * 2 * math.pi) * 8,
                  top: -20 + math.cos(_controller.value * 2 * math.pi) * 8,
                  child: RepaintBoundary(child: child!),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Positioned(
                  left: -28 + math.cos(_controller.value * 2 * math.pi) * 7,
                  bottom: -28 + math.sin(_controller.value * 2 * math.pi) * 7,
                  child: RepaintBoundary(child: child!),
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildUserHeader(deviceInfo, levelProvider),
                  const SizedBox(height: 10),
                  _buildDailyQuoteCard(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserHeader(
    DeviceInfoProvider deviceInfo,
    UserLevelProvider levelProvider,
  ) {
    final username = _user?.username ?? '';
    final isVip = _user?.isVip ?? false;
    final level = levelProvider.currentLevel;
    final levelColor = levelProvider.getLevelColor(level);
    final levelTitle = levelProvider.levelTitle;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.65), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: NetworkAvatarImage(
            imageUrl: _user?.avatar,
            radius: 24,
            backgroundColor: Colors.white.withOpacity(0.25),
            placeholderIcon: Icons.person_rounded,
            placeholderColor: Colors.white70,
          ),
        ),
        const SizedBox(width: 12),
        // Greeting + Name + Level
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreeting(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      username.isEmpty ? '萌友' : username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            color: Colors.black12,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVip) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VIP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              // Level badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: levelColor.withOpacity(0.5), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 9,
                      color: levelColor.withOpacity(0.9),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Lv.$level · $levelTitle',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Weather
        _buildWeatherWidget(deviceInfo),
      ],
    );
  }

  Widget _buildWeatherWidget(DeviceInfoProvider provider) {
    return GestureDetector(
      onTap: () async {
        try {
          final p = Provider.of<DeviceInfoProvider>(context, listen: false);
          await p.refreshLocalDeviceContext(
            requestLocationPermission: true,
            includeNetworkAndBattery: false,
          );
        } catch (_) {}
        if (mounted) await _loadWeatherData();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: _isLoadingWeather
            ? const SizedBox(
                width: 52,
                height: 36,
                child: Center(
                  child: MoeSmallLoading(color: Colors.white, size: 14),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weatherData?.getWeatherEmoji() ?? '☀️',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _weatherData != null ? '${_weatherData!.temp}°' : '26°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _getCity(provider),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDailyQuoteCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: Colors.white.withOpacity(0.5),
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            // No fixed SizedBox height — let content size naturally to avoid overflow
            child: DailyQuoteWidget(
              textColor: Colors.white.withOpacity(0.95),
              embedded: true,
            ),
          ),
        ],
      ),
    );
  }
}
