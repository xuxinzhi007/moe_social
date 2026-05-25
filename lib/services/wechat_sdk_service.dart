import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fluwx/fluwx.dart';

import '../utils/wechat_config.dart';

/// 封装 fluwx：注册 SDK、唤起微信授权并返回 code。
class WechatSdkService {
  WechatSdkService._();

  static final WechatSdkService instance = WechatSdkService._();

  final Fluwx _fluwx = Fluwx();
  bool _registered = false;
  FluwxCancelable? _subscriber;
  Completer<String>? _authCompleter;

  Future<void> ensureRegistered() async {
    if (kIsWeb) return;
    if (_registered) return;
    final ok = await _fluwx.registerApi(
      appId: WechatConfig.appId,
      doOnAndroid: true,
      doOnIOS: true,
      universalLink: WechatConfig.universalLink,
    );
    if (!ok) {
      throw StateError('微信 SDK 注册失败，请检查 AppID 与包名配置');
    }
    _subscriber ??= _fluwx.addSubscriber(_onWeChatResponse);
    _registered = true;
  }

  void _onWeChatResponse(WeChatResponse response) {
    if (response is! WeChatAuthResponse) return;
    final pending = _authCompleter;
    if (pending == null || pending.isCompleted) return;

    if (response.errCode != 0) {
      pending.completeError(
        StateError(
          _formatWechatAuthError(response.errCode ?? -1, response.errStr),
        ),
      );
      return;
    }
    final code = response.code?.trim() ?? '';
    if (code.isEmpty) {
      pending.completeError(StateError('微信未返回授权码'));
      return;
    }
    pending.complete(code);
  }

  /// 唤起微信授权，返回一次性 code（由后端换取 openid）。
  Future<String> requestAuthCode() async {
    if (kIsWeb) {
      throw StateError('微信登录仅支持 Android / iOS 客户端');
    }
    await ensureRegistered();
    if (!await _fluwx.isWeChatInstalled) {
      throw StateError('请先安装微信客户端');
    }
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      throw StateError('已有进行中的微信授权');
    }

    final completer = Completer<String>();
    _authCompleter = completer;
    try {
      final started = await _fluwx.authBy(
        which: NormalAuth(
          scope: 'snsapi_userinfo',
          state: 'moe_social',
        ),
      );
      if (!started) {
        throw StateError('无法唤起微信，请稍后重试');
      }
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          throw StateError('微信授权超时，请重试');
        },
      );
    } finally {
      _authCompleter = null;
    }
  }

  static String _formatWechatAuthError(int errCode, String? errStr) {
    final detail = errStr?.trim();
    if (errCode == 10005 ||
        (detail != null &&
            (detail.contains('10005') || detail.contains('scope')))) {
      return '微信返回 10005：当前 AppID 不是移动应用授权，或 VPS 与 App 的 AppID/Secret 不一致。'
          '请用 Moe Social Dev（${WechatConfig.appId}）凭证，并完整重装 App 后再试';
    }
    switch (errCode) {
      case -2:
        return '已取消微信授权';
      case -4:
        return '您拒绝了微信授权';
      case -6:
        return '微信授权失败：请在开放平台登记包名与签名（debug：com.example.moe_social.dev，release：com.example.moe_social）';
      default:
        if (detail != null && detail.isNotEmpty) {
          return '微信授权失败（$errCode）：$detail';
        }
        return '微信授权失败（$errCode），请确认使用开放平台「移动应用」AppID（${WechatConfig.appId}）';
    }
  }
}
