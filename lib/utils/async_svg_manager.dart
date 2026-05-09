import 'package:flutter/services.dart';
/**/

class AsyncSvgManager {
  static final AsyncSvgManager _instance = AsyncSvgManager._internal();
  factory AsyncSvgManager() => _instance;
  AsyncSvgManager._internal();

  final Map<String, String> _svgCache = {};
  final Map<String, Future<String>?> _loadingFutures = {};
  static const String _basePath = 'assets/svg/';

  static const List<String> _giftSvgList = [
    'heart', 'flower', 'thumbsup', 'clap', 'hug',
    'coffee', 'cake', 'ice_cream', 'wine', 'diamond',
    'crown', 'rocket', 'rainbow', 'fireworks', 'unicorn',
  ];

  Future<void> preloadAll({Duration? timeout}) async {
    final futures = _giftSvgList.map(loadSvg).toList();
    
    if (timeout != null) {
      await Future.wait(futures, eagerError: true).timeout(timeout, onTimeout: () {
        return [];
      });
    } else {
      await Future.wait(futures, eagerError: true);
    }
  }

  Future<String> loadSvg(String giftId) async {
    if (_svgCache.containsKey(giftId)) {
      return _svgCache[giftId]!;
    }

    if (_loadingFutures.containsKey(giftId)) {
      return _loadingFutures[giftId]!;
    }

    final future = _loadSvgInternal(giftId);
    _loadingFutures[giftId] = future;

    try {
      final content = await future;
      _svgCache[giftId] = content;
      return content;
    } finally {
      _loadingFutures.remove(giftId);
    }
  }

  Future<String> _loadSvgInternal(String giftId) async {
    try {
      return await rootBundle.loadString('$_basePath$giftId.svg');
    } catch (e) {
      return '';
    }
  }

  String? getSvg(String giftId) {
    return _svgCache[giftId];
  }

  bool isSvgLoaded(String giftId) {
    return _svgCache.containsKey(giftId);
  }

  Future<bool> waitForSvg(String giftId, {Duration timeout = const Duration(seconds: 5)}) async {
    if (isSvgLoaded(giftId)) {
      return true;
    }

    final future = _loadingFutures[giftId];
    if (future == null) {
      return false;
    }

    try {
      await future.timeout(timeout);
      return isSvgLoaded(giftId);
    } catch (_) {
      return false;
    }
  }

  void clearCache() {
    _svgCache.clear();
    _loadingFutures.clear();
  }

  int get cachedCount => _svgCache.length;
  int get loadingCount => _loadingFutures.length;
  List<String> get availableSvgIds => _svgCache.keys.toList();
  bool get hasPendingLoads => _loadingFutures.isNotEmpty;
}