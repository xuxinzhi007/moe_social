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

  factory WeatherData.fromOpenMeteo(
      Map<String, dynamic> response, String cityName) {
    final current = response['current_weather'] ?? response['current'];
    if (current is! Map) {
      throw const FormatException('Open-Meteo response has no current weather');
    }
    final weatherCode =
        _asInt(current['weathercode'] ?? current['weather_code']);
    final humidity = _firstHourlyValue(response, 'relative_humidity_2m');
    return WeatherData(
      city: cityName,
      temp: _formatNumber(current['temperature'], '°C'),
      text: _weatherCodeText(weatherCode),
      iconCode: _weatherCodeToIconCode(weatherCode),
      humidity: humidity == null ? '--' : '$humidity%',
      windDir: _formatNumber(
          current['winddirection'] ?? current['wind_direction'], '°'),
      windSpeed:
          _formatNumber(current['windspeed'] ?? current['wind_speed'], 'km/h'),
    );
  }

  static int _asInt(dynamic value) =>
      value is num ? value.round() : int.tryParse('$value') ?? -1;

  static String? _firstHourlyValue(Map<String, dynamic> response, String key) {
    final hourly = response['hourly'];
    if (hourly is Map &&
        hourly[key] is List &&
        (hourly[key] as List).isNotEmpty) {
      return '${(hourly[key] as List).first}';
    }
    return null;
  }

  static String _formatNumber(dynamic value, String suffix) {
    if (value is num) {
      final formatted =
          value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
      return '$formatted$suffix';
    }
    return value == null ? '--' : '$value$suffix';
  }

  static String _weatherCodeText(int code) {
    if (code == 0) return '晴';
    if (code <= 3) return '多云';
    if (code == 45 || code == 48) return '雾';
    if (code >= 51 && code <= 57) return '毛毛雨';
    if (code >= 61 && code <= 67 || code >= 80 && code <= 82) return '雨';
    if (code >= 71 && code <= 77 || code >= 85 && code <= 86) return '雪';
    if (code >= 95) return '雷雨';
    return '多云';
  }

  static String _weatherCodeToIconCode(int code) {
    if (code == 0) return '100';
    if (code <= 3) return '101';
    if (code == 45 || code == 48) return '150';
    if (code >= 71 && code <= 77 || code >= 85 && code <= 86) return '400';
    if (code >= 95) return '303';
    if (code >= 51 && code <= 67 || code >= 80 && code <= 82) return '305';
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
  static const String _weatherApiHost = 'api.open-meteo.com';
  static const String _weatherApiPath = '/v1/forecast';
  static const String _geocodingApiHost = 'geocoding-api.open-meteo.com';
  static const String _geocodingApiPath = '/v1/search';
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
          return WeatherData.fromOpenMeteo(cached, normalizedCity);
        }
      }

      final location = await _geocodeCity(normalizedCity);
      if (location == null) return null;
      return _getWeatherAtCoordinates(
        location.latitude,
        location.longitude,
        normalizedCity,
        prefs,
        cacheKey,
        now,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<WeatherData?> _getWeatherAtCoordinates(
      double latitude,
      double longitude,
      String cityName,
      SharedPreferences prefs,
      String cacheKey,
      int now) async {
    final response = await http
        .get(
          Uri.https(_weatherApiHost, _weatherApiPath, {
            'latitude': '$latitude',
            'longitude': '$longitude',
            'current_weather': 'true',
            'hourly': 'relative_humidity_2m',
            'timezone': 'auto',
            'forecast_days': '1',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    final apiData = jsonDecode(response.body) as Map<String, dynamic>;
    if (apiData['current_weather'] is! Map && apiData['current'] is! Map) {
      return null;
    }
    await prefs.setString(cacheKey, jsonEncode(apiData));
    await prefs.setInt('${cacheKey}_time', now);
    return WeatherData.fromOpenMeteo(apiData, cityName);
  }

  static Future<({double latitude, double longitude})?> _geocodeCity(
      String cityName) async {
    final response = await http
        .get(Uri.https(_geocodingApiHost, _geocodingApiPath, {
          'name': cityName,
          'count': '1',
          'language': 'zh',
          'format': 'json'
        }))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return null;
    }
    final results =
        (jsonDecode(response.body) as Map<String, dynamic>)['results'];
    if (results is! List || results.isEmpty || results.first is! Map) {
      return null;
    }
    final row = results.first as Map;
    final latitude = (row['latitude'] as num?)?.toDouble();
    final longitude = (row['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return (latitude: latitude, longitude: longitude);
  }

  static Future<WeatherData?> getWeatherByLocation(
      double lat, double lon) async {
    try {
      final cityName = _normalizeCityName(
        await ReverseGeocode.cityName(lat, lon, fallback: _defaultCity),
      );
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'weather_$cityName';
      final now = DateTime.now().millisecondsSinceEpoch;
      final cachedTime = prefs.getInt('${cacheKey}_time') ?? 0;
      if (now - cachedTime < _cacheDuration.inMilliseconds) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          return WeatherData.fromOpenMeteo(jsonDecode(cachedData), cityName);
        }
      }
      return _getWeatherAtCoordinates(lat, lon, cityName, prefs, cacheKey, now);
    } catch (_) {
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
