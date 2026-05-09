import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgResourceManager {
  static final SvgResourceManager _instance = SvgResourceManager._internal();
  factory SvgResourceManager() => _instance;
  SvgResourceManager._internal();

  final Map<String, String> _svgContentCache = {};
  final Map<String, bool> _loadingStatus = {};
  final Map<String, List<Function()>> _loadingCallbacks = {};

  static const String _basePath = 'assets/svg/';
  static const List<String> _defaultGiftIds = [
    'heart',
    'flower',
    'thumbsup',
    'clap',
    'hug',
    'coffee',
    'cake',
    'ice_cream',
    'wine',
    'diamond',
    'crown',
    'rocket',
    'rainbow',
    'fireworks',
    'unicorn',
  ];

  Future<void> preloadAll() async {
    await Future.wait(_defaultGiftIds.map((id) => loadSvg(id)));
  }

  Future<void> preloadGifts(List<String> giftIds) async {
    await Future.wait(giftIds.map((id) => loadSvg(id)));
  }

  Future<String> loadSvg(String giftId) async {
    if (_svgContentCache.containsKey(giftId)) {
      return _svgContentCache[giftId]!;
    }

    final callbacks = _loadingCallbacks.putIfAbsent(giftId, () => []);
    if (_loadingStatus[giftId] == true) {
      final completer = Completer<String>();
      callbacks.add(() => completer.complete(_svgContentCache[giftId]!));
      return completer.future;
    }

    _loadingStatus[giftId] = true;

    try {
      final svgContent = await rootBundle.loadString('$_basePath$giftId.svg');
      _svgContentCache[giftId] = svgContent;

      for (final callback in callbacks) {
        callback();
      }
      _loadingCallbacks[giftId]?.clear();

      return svgContent;
    } catch (e) {
      debugPrint('Failed to load SVG for gift $giftId: $e');
      _loadingStatus[giftId] = false;
      for (final callback in callbacks) {
        callback();
      }
      _loadingCallbacks[giftId]?.clear();
      return '';
    }
  }

  String? getSvgContent(String giftId) {
    return _svgContentCache[giftId];
  }

  bool isLoaded(String giftId) {
    return _svgContentCache.containsKey(giftId);
  }

  bool isLoading(String giftId) {
    return _loadingStatus[giftId] ?? false;
  }

  void clearCache() {
    _svgContentCache.clear();
    _loadingStatus.clear();
    _loadingCallbacks.clear();
  }

  Widget buildSvgWidget(
    String giftId, {
    double width = 64,
    double height = 64,
    Color? color,
    Animation<double>? animation,
  }) {
    final svgContent = _svgContentCache[giftId];
    if (svgContent != null && svgContent.isNotEmpty) {
      Widget child = SvgPicture.string(
        svgContent,
        width: width,
        height: height,
        colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
        fit: BoxFit.contain,
      );

      if (animation != null) {
        child = AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: Tween<double>(begin: 0.0, end: 1.0)
                  .chain(CurveTween(curve: Curves.elasticOut))
                  .evaluate(animation),
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: child,
        );
      }

      return child;
    }

    return SizedBox(width: width, height: height);
  }
}

class SvgPictureProvider {
  static Widget getOrPlaceholder(
    String giftId, {
    double width = 64,
    double height = 64,
    Color? color,
    required String placeholder,
  }) {
    final manager = SvgResourceManager();
    if (manager.isLoaded(giftId)) {
      return manager.buildSvgWidget(
        giftId,
        width: width,
        height: height,
        color: color,
      );
    }
    return Text(placeholder, style: TextStyle(fontSize: width * 0.8));
  }
}
