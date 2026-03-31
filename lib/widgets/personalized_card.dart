import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'daily_quote_widget.dart';
import '../providers/device_info_provider.dart';
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryUpdateLocation();
      _loadWeatherData();
    });
  }

  void _tryUpdateLocation() {
    try {
      final provider = Provider.of<DeviceInfoProvider>(context, listen: false);
      if (provider.locationText.isEmpty) {
        provider.syncDeviceInfoToServer(requestLocationPermission: true);
      }
    } catch (_) {}
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
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.antiAlias,
            children: [
              // Positioned 必须是 Stack 的直接子节点，RepaintBoundary 只能放在 Positioned 内部。
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Positioned(
                    right: -30 + math.sin(_controller.value * 2 * math.pi) * 15,
                    top: -30 + math.cos(_controller.value * 2 * math.pi) * 15,
                    child: RepaintBoundary(child: child!),
                  );
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Positioned(
                    left: -40 + math.cos(_controller.value * 2 * math.pi) * 12,
                    bottom: -40 + math.sin(_controller.value * 2 * math.pi) * 12,
                    child: RepaintBoundary(child: child!),
                  );
                },
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '今天也要开心呀',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
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
                      GestureDetector(
                        onTap: _loadWeatherData,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _isLoadingWeather
                              ? const SizedBox(
                                  width: 80,
                                  height: 40,
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      _getCity(deviceInfo),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _getWeatherIcon(),
                                          style: TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _getWeatherText(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              color: Colors.white.withOpacity(0.6),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '每日一言',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DailyQuoteWidget(
                          textColor: Colors.white,
                          embedded: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
