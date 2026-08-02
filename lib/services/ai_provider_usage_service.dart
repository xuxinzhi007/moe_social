import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_provider_profile.dart';

class ProviderTokenUsage {
  const ProviderTokenUsage({
    required this.name,
    required this.totalGranted,
    required this.totalUsed,
    required this.totalAvailable,
    required this.unlimitedQuota,
  });

  final String name;
  final double totalGranted;
  final double totalUsed;
  final double totalAvailable;
  final bool unlimitedQuota;

  static ProviderTokenUsage? fromResponse(Map<String, dynamic> response) {
    final raw = response['data'];
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    if (data['object']?.toString() != 'token_usage') return null;
    double number(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return ProviderTokenUsage(
      name: data['name']?.toString() ?? '',
      totalGranted: number('total_granted'),
      totalUsed: number('total_used'),
      totalAvailable: number('total_available'),
      unlimitedQuota: data['unlimited_quota'] == true,
    );
  }
}

/// Reads the quota exposed by New API-compatible gateways such as Xbai.
class AiProviderUsageService {
  Future<ProviderTokenUsage?> fetchTokenUsage(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    if (profile.baseUrl.trim().isEmpty || apiKey.trim().isEmpty) return null;
    final source = Uri.tryParse(profile.baseUrl.trim());
    if (source == null || source.scheme.isEmpty || source.host.isEmpty) {
      return null;
    }
    final uri = source.replace(path: '/api/usage/token/', query: null);
    try {
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer ${apiKey.trim()}'
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return ProviderTokenUsage.fromResponse(
          Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
