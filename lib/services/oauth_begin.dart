import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/oauth_authorize_url.dart';
import '../utils/oauth_flow_helper.dart';
import '../utils/oauth_pkce.dart';
import 'auth_flow_service.dart';
import 'oauth_pending_store.dart';

/// 一次成功发起的授权。
class OauthBegin {
  const OauthBegin({
    required this.provider,
    required this.flow,
    required this.authorizeUrl,
    required this.state,
    required this.returnUrl,
  });

  final String provider;
  final String flow;

  /// 供应商授权页地址；微信 `flow=app` 时为空（SDK 进程内唤起，没有要跳的 URL）。
  final String authorizeUrl;

  /// 服务端下发的一次性 state，已绑定回跳地址 / challenge / 供应商配置 / 期限。
  final String state;

  final String returnUrl;
}

/// 授权发起：生成 PKCE verifier、向服务端换 state、把事务记到本地。
///
/// 单独成一层而不是散在登录页的三个分支里，是因为「verifier 只留在本地、
/// 存储失败就不许跳转」这条约束必须只有一处实现。
class OauthBeginService {
  OauthBeginService._();

  static const String feishu = 'feishu';
  static const String wechat = 'wechat';

  static Future<OauthBegin> feishuAuth() => _begin(feishu, '');

  /// [flow]：`app` 原生 SDK · `website` 扫码 · `mp` 公众号网页。
  static Future<OauthBegin> wechatAuth(String flow) => _begin(wechat, flow);

  static Future<OauthBegin> _begin(String provider, String flow) async {
    final verifier = generateCodeVerifier();
    final isNativeSdkFlow = provider == wechat && flow == 'app';
    final returnUrl =
        isNativeSdkFlow ? '' : _returnUrlFor(provider);

    final OauthAuthorizeUrl auth = provider == feishu
        ? await AuthFlowService.getFeishuAuthorizeUrl(
            returnUrl: returnUrl,
            codeChallenge: s256CodeChallenge(verifier),
          )
        : await AuthFlowService.getWechatAuthorizeUrl(
            flow: flow,
            returnUrl: returnUrl,
            codeChallenge: s256CodeChallenge(verifier),
          );

    if (auth.state.isEmpty) {
      throw StateError('服务端未下发 state，无法安全发起授权');
    }
    if (!isNativeSdkFlow && !auth.hasAuthorizeUrl) {
      throw StateError('服务端未下发授权地址');
    }

    // 写失败会抛出，调用方必须就此中止：没有这条记录，回调回来换不出登录态，
    // 让用户走完整个授权再失败比现在就说清楚更糟。
    await OauthPendingStore.save(
      OauthPendingAuth(
        provider: provider,
        flow: flow,
        state: auth.state,
        codeVerifier: verifier,
        returnUrl: returnUrl,
        expiresAt: OauthPendingStore.defaultExpiry(),
      ),
    );

    return OauthBegin(
      provider: provider,
      flow: flow,
      authorizeUrl: auth.authorizeUrl,
      state: auth.state,
      returnUrl: returnUrl,
    );
  }

  static String _returnUrlFor(String provider) {
    if (kIsWeb) return webOAuthReturnUrl();
    return provider == feishu
        ? feishuAppOAuthReturnUri
        : wechatAppOAuthReturnUri;
  }
}
