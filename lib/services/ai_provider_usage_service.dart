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

/// One consumption row from New API `GET /api/log/token?key=...`.
///
/// Public token logs expose gateway `quota` points, not prompt/completion
/// token splits or RMB. Prefer this over inventing currency conversions.
class ProviderTokenLogEntry {
  const ProviderTokenLogEntry({
    required this.id,
    required this.quota,
    required this.modelName,
    required this.createdAt,
    this.promptTokens,
    this.completionTokens,
  });

  final int id;
  final double quota;
  final String modelName;
  final int createdAt;
  final int? promptTokens;
  final int? completionTokens;

  static ProviderTokenLogEntry? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final quota = (json['quota'] as num?)?.toDouble();
    if (id == null || quota == null) return null;
    final prompt = (json['prompt_tokens'] as num?)?.toInt();
    final completion = (json['completion_tokens'] as num?)?.toInt();
    return ProviderTokenLogEntry(
      id: id,
      quota: quota,
      modelName: json['model_name']?.toString() ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      promptTokens: prompt,
      completionTokens: completion,
    );
  }
}

/// Reads the quota exposed by New API-compatible gateways such as Xbai.
class AiProviderUsageService {
  Future<ProviderTokenUsage?> fetchTokenUsage(
    AiProviderProfile profile,
    String apiKey,
  ) async {
    final source = _originOf(profile);
    if (source == null || apiKey.trim().isEmpty) return null;
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

  /// Latest consumption log for this API key (New API public token log).
  ///
  /// Useful for per-turn quota. Xbai/New API often omit prompt/completion
  /// fields here; when absent, callers should show quota points only.
  Future<ProviderTokenLogEntry?> fetchLatestTokenLog(
    AiProviderProfile profile,
    String apiKey, {
    int? afterId,
    int? notBeforeUnix,
  }) async {
    final source = _originOf(profile);
    final key = apiKey.trim();
    if (source == null || key.isEmpty) return null;
    final uri = source.replace(
      path: '/api/log/token',
      queryParameters: {'key': key},
    );
    try {
      final response = await http.get(uri, headers: const {
        'Content-Type': 'application/json'
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['success'] == false) return null;
      final raw = map['data'];
      if (raw is! List) return null;
      ProviderTokenLogEntry? best;
      for (final item in raw) {
        if (item is! Map) continue;
        final entry =
            ProviderTokenLogEntry.fromJson(Map<String, dynamic>.from(item));
        if (entry == null) continue;
        if (afterId != null && entry.id <= afterId) continue;
        if (notBeforeUnix != null &&
            entry.createdAt > 0 &&
            entry.createdAt < notBeforeUnix) {
          continue;
        }
        if (best == null ||
            entry.createdAt > best.createdAt ||
            (entry.createdAt == best.createdAt && entry.id > best.id)) {
          best = entry;
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  Uri? _originOf(AiProviderProfile profile) {
    if (profile.baseUrl.trim().isEmpty) return null;
    final source = Uri.tryParse(profile.baseUrl.trim());
    if (source == null || source.scheme.isEmpty || source.host.isEmpty) {
      return null;
    }
    return source;
  }
}
