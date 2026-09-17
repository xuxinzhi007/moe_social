import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../utils/oauth_flow_helper.dart';
import '../../utils/webview_platform_init.dart';
import 'feishu_login_result.dart';

/// 仅负责在 WebView 里完成飞书授权，并把回跳带上的一次性 ticket 交回登录页。
///
/// 授权地址与期望的 state 由登录页在发起阶段备好：verifier 的生成与本地保管
/// 只有一处实现（`OauthBeginService`），这个页面碰不到它，也就不可能把它泄漏出去。
class FeishuLoginPage extends StatefulWidget {
  const FeishuLoginPage({
    super.key,
    required this.authorizeUrl,
    required this.expectedState,
    required this.returnUrl,
  });

  final String authorizeUrl;
  final String expectedState;

  /// 服务端 302 的目标；只有精确命中它的那一跳才被视为授权结果。
  final String returnUrl;

  @override
  State<FeishuLoginPage> createState() => _FeishuLoginPageState();
}

class _FeishuLoginPageState extends State<FeishuLoginPage> {
  WebViewController? _controller;
  var _loading = true;
  var _returning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      ensureWebViewPlatformInitialized();
      if (WebViewPlatform.instance == null) {
        throw Exception('当前环境无法使用内置授权页，请升级 App 后重试');
      }
      final controller = WebViewController();
      // Web 端 webview_flutter 未实现 setJavaScriptMode，跳过即可。
      if (!kIsWeb) {
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      }
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (pageUrl) {
            if (mounted && !_returning) setState(() => _loading = true);
            _tryReturnTicket(pageUrl);
          },
          onPageFinished: (_) {
            if (mounted && !_returning) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final callback = _matchReturn(request.url);
            if (callback != null) {
              _returnTicketToLogin(callback);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) => _tryReturnTicket(change.url),
          onWebResourceError: (err) {
            if (!mounted || _returning) return;
            setState(() {
              _error = err.description;
              _loading = false;
            });
          },
        ),
      );
      await controller.loadRequest(Uri.parse(widget.authorizeUrl));
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _tryReturnTicket(String? raw) {
    final callback = _matchReturn(raw);
    if (callback != null) _returnTicketToLogin(callback);
  }

  /// 只认「服务端 302 到本次回跳地址」这一跳上的 oauth_ticket。
  ///
  /// 旧实现在任意 URL 上看到 `code` 参数就截获 —— 授权过程中的任何一跳
  /// 只要带上 `?code=…` 就会被当成最终结果，中间页的凭证冒充了回调。
  /// 现在地址必须精确等于本次的 [FeishuLoginPage.returnUrl]，state 也必须匹配。
  OauthCallback? _matchReturn(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || !_isExpectedReturn(uri)) return null;
    final callback = OauthCallback.fromUri(uri);
    if (callback == null || !callback.isValid) return null;
    if (callback.state != widget.expectedState) return null;
    return callback;
  }

  bool _isExpectedReturn(Uri uri) {
    final expected = Uri.tryParse(widget.returnUrl);
    if (expected == null || expected.host.isEmpty) return false;
    if (uri.scheme != expected.scheme ||
        uri.host != expected.host ||
        uri.port != expected.port) {
      return false;
    }
    return _normalizePath(uri.path) == _normalizePath(expected.path);
  }

  static String _normalizePath(String path) {
    if (path.isEmpty) return '/';
    var normalized = path;
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void _returnTicketToLogin(OauthCallback callback) {
    if (_returning || !mounted) return;
    _returning = true;
    Navigator.of(context).pop(
      FeishuLoginResult.authorized(
        ticket: callback.ticket,
        state: callback.state,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_returning,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('飞书授权'),
        ),
        body: Stack(
          children: [
            if (_controller != null && !_returning)
              WebViewWidget(controller: _controller!),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loading = true;
                            _controller = null;
                            _returning = false;
                          });
                          _initWebView();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_loading || _returning)
              const ColoredBox(
                color: Color(0xCCFFFFFF),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在获取授权…'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
