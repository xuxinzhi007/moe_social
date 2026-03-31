import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  factory WeatherData.fromJson(Map<String, dynamic> json, String cityName) {
    final now = json['now'] as Map<String, dynamic>;
    return WeatherData(
      city: cityName,
      temp: now['temp'] as String,
      text: now['text'] as String,
      iconCode: now['icon'] as String,
      humidity: now['humidity'] as String,
      windDir: now['windDir'] as String,
      windSpeed: now['windSpeed'] as String,
    );
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
  static const String _apiKey = '0971b773e8ea4db386ae892ea02dc905';
  static const String _baseUrl = 'https://devapi.qweather.com/v7';
  static const Duration _cacheDuration = Duration(minutes: 30);

  static Future<WeatherData?> getWeatherByCity(String cityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'weather_$cityName';
      final cachedTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cachedTime < _cacheDuration.inMilliseconds) {
        final cachedData = prefs.getString(cacheKey);
        if (cachedData != null) {
          return WeatherData.fromJson(
            jsonDecode(cachedData) as Map<String, dynamic>,
            cityName,
          );
        }
      }

      final locationResponse = await http.get(
        Uri.parse('$_baseUrl/city/lookup?location=$cityName&key=$_apiKey'),
      );

      if (locationResponse.statusCode != 200) {
        return null;
      }

      final locationData = jsonDecode(locationResponse.body) as Map<String, dynamic>;
      if (locationData['code'] != '200') {
        return null;
      }

      final locations = locationData['location'] as List;
      if (locations.isEmpty) {
        return null;
      }

      final locationId = locations[0]['id'] as String;

      final weatherResponse = await http.get(
        Uri.parse('$_baseUrl/weather/now?location=$locationId&key=$_apiKey'),
      );

      if (weatherResponse.statusCode != 200) {
        return null;
      }

      final weatherData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      if (weatherData['code'] != '200') {
        return null;
      }

      await prefs.setString(cacheKey, jsonEncode(weatherData));
      await prefs.setInt('${cacheKey}_time', now);

      return WeatherData.fromJson(weatherData, cityName);
    } catch (e) {
      return null;
    }
  }

  static Future<WeatherData?> getWeatherByLocation(double lat, double lon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'weather_${lat}_$lon';
      final cachedTime = prefs.getInt('${cacheKey}_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - cachedTime < _cacheDuration.inMilliseconds) {
        final cachedData = prefs.getString(cacheKey);
        final cachedCity = prefs.getString('${cacheKey}_city');
        if (cachedData != null && cachedCity != null) {
          return WeatherData.fromJson(
            jsonDecode(cachedData) as Map<String, dynamic>,
            cachedCity,
          );
        }
      }

      final weatherResponse = await http.get(
        Uri.parse('$_baseUrl/weather/now?location=$lon,$lat&key=$_apiKey'),
      );

      if (weatherResponse.statusCode != 200) {
        return null;
      }

      final weatherData = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      if (weatherData['code'] != '200') {
        return null;
      }

      final locationResponse = await http.get(
        Uri.parse('$_baseUrl/city/lookup?location=$lon,$lat&key=$_apiKey'),
      );

      String cityName = '未知城市';
      if (locationResponse.statusCode == 200) {
        final locationData = jsonDecode(locationResponse.body) as Map<String, dynamic>;
        if (locationData['code'] == '200') {
          final locations = locationData['location'] as List;
          if (locations.isNotEmpty) {
            cityName = locations[0]['name'] as String;
          }
        }
      }

      await prefs.setString(cacheKey, jsonEncode(weatherData));
      await prefs.setInt('${cacheKey}_time', now);
      await prefs.setString('${cacheKey}_city', cityName);

      return WeatherData.fromJson(weatherData, cityName);
    } catch (e) {
      return null;
    }
  }
}
