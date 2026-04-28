import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'daily_quote_widget.dart';
import '../providers/device_info_provider.dart';
import 'moe_loading.dart';
import '../services/weather_service.dart';

class PersonalizedCard extends StatefulWidget {
  const PersonalizedCard({super.key});

  @override
  State<PersonalizedCard> createState() => _PersonalizedCardState();
}

class _PersonalizedCardState extends State<PersonalizedCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  Future<void> _loadWeatherData() async {
    if (_isLoadingWeather) return;
    
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      final provider = Provider.of<DeviceInfoProvider>(context, listen: false);
      
      if (provider.latitude != null && provider.longitude != null) {
        final weather = await WeatherService.getWeatherByLocation(
          provider.latitude!,
          provider.longitude!,
        );
        if (weather != null) {
          setState(() {
            _weatherData = weather;
          });
          return;
        }
      }
      
      final cityName = _getCity(provider);
      final weather = await WeatherService.getWeatherByCity(cityName);
      if (weather != null) {
        setState(() {
          _weatherData = weather;
        });
      }
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
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
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _getWeatherIcon() {
    if (_weatherData != null) {
      return _weatherData!.getWeatherEmoji();
    }
    return '☀️';
  }

  String _getCity(DeviceInfoProvider provider) {
    if (_weatherData != null) {
      return _weatherData!.city;
    }
    final locationText = provider.locationText;
    if (locationText.isEmpty || locationText.contains('失败') || locationText.contains('权限') || locationText.contains('开启')) {
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

  String _getWeatherText() {
    if (_weatherData != null) {
      return '${_weatherData!.temp}°C ${_weatherData!.text}';
    }
    return '26°C 晴朗';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceInfoProvider>(
      builder: (context, deviceInfo, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF667eea),
                const Color(0xFF764ba2),
                const Color(0xFFf093fb),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Stack(
                      clipBehavior: Clip.antiAlias,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Positioned(
                              right: -25 + math.sin(_controller.value * 2 * math.pi) * 10,
                              top: -25 + math.cos(_controller.value * 2 * math.pi) * 10,
                              child: RepaintBoundary(child: child!),
                            );
                          },
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Positioned(
                              left: -35 + math.cos(_controller.value * 2 * math.pi) * 8,
                              bottom: -35 + math.sin(_controller.value * 2 * math.pi) * 8,
                              child: RepaintBoundary(child: child!),
                            );
                          },
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '今天也要开心呀',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.8,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black12,
                                              offset: Offset(0, 2),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(child: _buildWeatherWidget(deviceInfo)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Flexible(
                              fit: FlexFit.loose,
                              child: _buildDailyQuoteCard(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWeatherWidget(DeviceInfoProvider deviceInfo) {
    return GestureDetector(
      onTap: () async {
        try {
          final p = Provider.of<DeviceInfoProvider>(
              context,
              listen: false);
          await p.refreshLocalDeviceContext(
            requestLocationPermission: true,
            includeNetworkAndBattery: false,
          );
        } catch (_) {}
        if (mounted) await _loadWeatherData();
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: _isLoadingWeather
            ? const SizedBox(
                width: 60,
                height: 36,
                child: Center(
                  child: MoeSmallLoading(
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _getWeatherIcon(),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _getWeatherText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _getCity(deviceInfo),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '每日一言',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
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
