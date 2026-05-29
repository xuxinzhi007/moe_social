import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// 错误展示的业务场景（决定标题文案）。
enum MoeErrorScene {
  generic,
  contacts,
  feed,
  community,
  profile,
  followers,
  following,
  pageLoad,
}

/// 错误类型（决定副文案与图标）。
enum MoeErrorKind {
  network,
  timeout,
  auth,
  server,
  notFound,
  generic,
}

/// 统一错误展示模型（标题 + 副文案 + 图标 + 按钮文案）。
class MoeErrorPresentation {
  const MoeErrorPresentation({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel = '重新加载',
    this.toastMessage,
  });

  final MoeErrorKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final String? toastMessage;

  String get shortMessage => toastMessage ?? subtitle;
}

/// 全 App 错误文案 SSOT。
///
/// 页面/Toast 禁止直接展示 [ApiException.message] 或 `e.toString()`，
/// 统一调用 [resolve] / [toast].
abstract final class MoeErrorCopy {
  static const String networkSubtitle = '网络不太稳定，请检查连接后重试';
  static const String timeoutSubtitle = '加载有点慢，稍后再试一次吧';
  static const String serverSubtitle = '服务暂时不可用，请稍后再试';
  static const String genericSubtitle = '出了点小状况，请稍后再试';
  static const String authSubtitle = '登录后即可继续使用';

  /// 将任意异常解析为用户可读的错误展示。
  static MoeErrorPresentation resolve(
    Object? error, {
    MoeErrorScene scene = MoeErrorScene.generic,
  }) {
    final kind = _classify(error);
    return MoeErrorPresentation(
      kind: kind,
      title: _titleFor(scene, kind, error),
      subtitle: _subtitleFor(kind, error),
      icon: _iconFor(kind),
      actionLabel: _actionLabelFor(kind),
      toastMessage: _toastFor(scene, kind, error),
    );
  }

  /// Toast / SnackBar 用的短文案。
  static String toast(
    Object? error, {
    MoeErrorScene scene = MoeErrorScene.generic,
  }) {
    return resolve(error, scene: scene).shortMessage;
  }

  static MoeErrorKind _classify(Object? error) {
    if (error is ApiException) {
      final code = error.code;
      if (code == 401) return MoeErrorKind.auth;
      if (code == 403) return MoeErrorKind.auth;
      if (code == 404) return MoeErrorKind.notFound;
      if (code == 500 || code == 502 || code == 503) {
        return _messageLooksLikeNetwork(error.message)
            ? MoeErrorKind.network
            : MoeErrorKind.server;
      }
      if (code == 504) return MoeErrorKind.timeout;
    }

    final raw = _rawMessage(error).toLowerCase();
    if (raw.contains('请先登录') || raw.contains('登录')) {
      return MoeErrorKind.auth;
    }
    if (_messageLooksLikeTimeout(raw)) return MoeErrorKind.timeout;
    if (_messageLooksLikeNetwork(raw)) return MoeErrorKind.network;
    if (raw.contains('服务器') || raw.contains('server')) {
      return MoeErrorKind.server;
    }
    if (raw.contains('不存在') || raw.contains('not found')) {
      return MoeErrorKind.notFound;
    }
    return MoeErrorKind.generic;
  }

  static bool _messageLooksLikeNetwork(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('无法连接') ||
        lower.contains('网络') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection refused') ||
        lower.contains('failed host lookup');
  }

  static bool _messageLooksLikeTimeout(String raw) {
    return raw.contains('超时') ||
        raw.contains('timeout') ||
        raw.contains('timed out');
  }

  static String _rawMessage(Object? error) {
    if (error == null) return '';
    if (error is ApiException) return error.message;
    return error.toString();
  }

  static String _titleFor(
    MoeErrorScene scene,
    MoeErrorKind kind,
    Object? error,
  ) {
    if (kind == MoeErrorKind.auth) {
      return switch (scene) {
        MoeErrorScene.contacts => '登录后查看同好与人脉',
        MoeErrorScene.profile => '登录后查看个人资料',
        _ => '请先登录',
      };
    }

    return switch (scene) {
      MoeErrorScene.contacts => '暂时没能加载同好',
      MoeErrorScene.feed => '暂时没能加载动态',
      MoeErrorScene.community => '暂时没能加载圈子',
      MoeErrorScene.profile => '暂时没能加载资料',
      MoeErrorScene.followers => '暂时没能加载粉丝',
      MoeErrorScene.following => '暂时没能加载关注',
      MoeErrorScene.pageLoad => '页面加载失败',
      MoeErrorScene.generic => switch (kind) {
          MoeErrorKind.network => '网络好像断开了',
          MoeErrorKind.timeout => '加载超时了',
          MoeErrorKind.server => '服务暂时不可用',
          MoeErrorKind.notFound => '内容不存在',
          MoeErrorKind.auth => '请先登录',
          MoeErrorKind.generic => '加载失败了',
        },
    };
  }

  static String _subtitleFor(MoeErrorKind kind, Object? error) {
    if (kind == MoeErrorKind.auth) return authSubtitle;
    if (kind == MoeErrorKind.notFound) {
      return '这条内容可能已被删除或暂时不可见';
    }

    final raw = _rawMessage(error);
    // 业务层返回的短句（非网络类）可保留，但过滤技术向长句
    if (raw.isNotEmpty &&
        raw.length <= 40 &&
        !_messageLooksLikeNetwork(raw) &&
        !_messageLooksLikeTimeout(raw) &&
        !raw.contains('服务器是否开启')) {
      return raw;
    }

    return switch (kind) {
      MoeErrorKind.network => networkSubtitle,
      MoeErrorKind.timeout => timeoutSubtitle,
      MoeErrorKind.server => serverSubtitle,
      MoeErrorKind.notFound => '请返回后重试',
      MoeErrorKind.auth => authSubtitle,
      MoeErrorKind.generic => genericSubtitle,
    };
  }

  static String _toastFor(
    MoeErrorScene scene,
    MoeErrorKind kind,
    Object? error,
  ) {
    if (kind == MoeErrorKind.auth) return authSubtitle;
    return switch (scene) {
      MoeErrorScene.profile => '暂时没能加载资料，请检查网络',
      MoeErrorScene.contacts => '暂时没能加载同好，请检查网络',
      MoeErrorScene.feed => '暂时没能加载动态，请检查网络',
      MoeErrorScene.community => '暂时没能加载圈子，请检查网络',
      _ => _subtitleFor(kind, error),
    };
  }

  static IconData _iconFor(MoeErrorKind kind) {
    return switch (kind) {
      MoeErrorKind.network => Icons.wifi_off_rounded,
      MoeErrorKind.timeout => Icons.hourglass_empty_rounded,
      MoeErrorKind.server => Icons.cloud_off_rounded,
      MoeErrorKind.notFound => Icons.search_off_rounded,
      MoeErrorKind.auth => Icons.lock_outline_rounded,
      MoeErrorKind.generic => Icons.error_outline_rounded,
    };
  }

  static String _actionLabelFor(MoeErrorKind kind) {
    return switch (kind) {
      MoeErrorKind.auth => '去登录',
      _ => '重新加载',
    };
  }
}
