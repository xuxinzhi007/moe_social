import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/reverse_geocode.dart';

class WeatherData {
  final String city;
  final String temp;
  final String text;
  final String iconCode;
  final String humidity;
  final String windDir;
  final String windSpeed;

  WeatherData({
    required this.city,
    required this.temp,
    required this.text,
    required this.iconCode,
    required this.humidity,
    required this.windDir,
    required this.windSpeed,
  });

  factory WeatherData.fromApiRow(Map<String, dynamic> row, String cityName) {
    final weatherText = (row['tianqi'] ?? '').toString();
    final temperatureText = (row['wendu'] ?? '').toString();
    final windText = (row['fengdu'] ?? '').toString();
    final (windDir, windSpeed) = _splitWindInfo(windText);
    return WeatherData(
      city: cityName,
      temp: _extractDisplayTemp(temperatureText),
      text: weatherText,
      iconCode: _weatherTextToIconCode(weatherText),
      humidity: (row['pm'] ?? '--').toString(),
      windDir: windDir,
      windSpeed: windSpeed,
    );
  }

  static String _extractDisplayTemp(String raw) {
    if (raw.contains('～')) {
      final parts = raw.split('～');
      if (parts.length >= 2) {
        return parts.last.trim();
      }
    }
    if (raw.contains('~')) {
      final parts = raw.split('~');
      if (parts.length >= 2) {
        return parts.last.trim();
      }
    }
    return raw.trim().isEmpty ? '--' : raw.trim();
  }

  static (String, String) _splitWindInfo(String raw) {
    final txt = raw.trim();
    if (txt.isEmpty) return ('--', '--');
    if (txt.contains('-')) {
      final parts = txt.split('-');
      if (parts.length >= 2) {
        return (parts.first.trim(), parts.last.trim());
      }
    }
    return (txt, '--');
  }

  static String _weatherTextToIconCode(String text) {
    if (text.contains('雷')) return '303';
    if (text.contains('雪')) return '400';
    if (text.contains('雨')) return '305';
    if (text.contains('阴') || text.contains('云')) return '101';
    if (text.contains('晴')) return '100';
    if (text.contains('雾') || text.contains('霾')) return '150';
    return '101';
  }

  String getWeatherEmoji() {
    final iconMap = {
      '100': '☀️',
      '101': '⛅',
      '102': '⛅',
      '103': '☁️',
      '104': '☁️',
      '150': '🌫️',
      '151': '🌫️',
      '152': '🌫️',
      '153': '🌫️',
      '154': '🌫️',
      '300': '🌦️',
      '301': '🌦️',
      '302': '🌧️',
      '303': '⛈️',
      '304': '⛈️',
      '305': '🌧️',
      '306': '🌧️',
      '307': '🌧️',
      '308': '🌧️',
      '309': '🌧️',
      '310': '🌧️',
      '311': '🌧️',
      '312': '🌧️',
      '313': '🌧️',
      '314': '🌧️',
      '315': '🌧️',
      '316': '🌧️',
      '317': '🌧️',
      '318': '🌧️',
      '350': '🌨️',
      '351': '🌨️',
      '399': '🌨️',
      '400': '❄️',
      '401': '❄️',
      '402': '❄️',
      '403': '❄️',
      '404': '❄️',
      '405': '❄️',
      '406': '❄️',
      '407': '❄️',
      '408': '❄️',
      '409': '❄️',
      '410': '❄️',
    };
    return iconMap[iconCode] ?? '🌤️';
  }
}

class WeatherService {
  // 免费天气接口（按城市查询，返回未来多日数据）。
  static const String _weatherApiHost = 'v.api.aa1.cn';
  static const String _weatherApiPath = '/api/api-tianqi-3/index.php';
  static const Duration _cacheDuration = Duration(minutes: 30);
  static const String _defaultCity = '深圳';

  static Future<WeatherData?> getWeatherByCity(String cityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final normalizedCity = _normalizeCityName(cityName);
      final cacheKey = 'weather_$normalizedCity';
      final cachedTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cachedTime < _cacheDuration.inMilliseconds) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          final cached = jsonDecode(cachedData) as Map<String, dynamic>;
          return WeatherData.fromApiRow(
            cached,
            normalizedCity,
          );
        }
      }

      final response = await http.get(
        Uri.https(_weatherApiHost, _weatherApiPath, {
          'msg': normalizedCity,
          'type': '1',
        }),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final apiData = jsonDecode(response.body) as Map<String, dynamic>;
      if ((apiData['code'] ?? '').toString() != '1') {
        return null;
      }
      final list = apiData['data'];
      if (list is! List ||
          list.isEmpty ||
          list.first is! Map<String, dynamic>) {
        return null;
      }
      final firstRow = list.first as Map<String, dynamic>;
      await prefs.setString(cacheKey, jsonEncode(firstRow));
      await prefs.setInt('${cacheKey}_time', now);
      return WeatherData.fromApiRow(firstRow, normalizedCity);
    } catch (e) {
      return null;
    }
  }

  static Future<WeatherData?> getWeatherByLocation(
      double lat, double lon) async {
    try {
      final cityName = _normalizeCityName(
        await ReverseGeocode.cityName(
          lat,
          lon,
          fallback: _defaultCity,
        ),
      );
      return getWeatherByCity(cityName);
    } catch (e) {
      return null;
    }
  }

  static String _normalizeCityName(String cityName) {
    final raw = cityName.trim();
    if (raw.isEmpty) return _defaultCity;
    final cleaned = raw.replaceAll(RegExp(r'(省|市|区|县|自治州|特别行政区)$'), '').trim();
    return cleaned.isEmpty ? _defaultCity : cleaned;
  }
}
