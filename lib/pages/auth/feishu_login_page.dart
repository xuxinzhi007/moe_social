import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../services/api_client.dart';
import '../../services/auth_flow_service.dart';
import '../../utils/feishu_oauth_helper.dart';
import '../../utils/webview_platform_init.dart';
import 'feishu_login_result.dart';

/// 仅负责飞书授权并带回 [code]；登录页显示 loading 并换 token。
class FeishuLoginPage extends StatefulWidget {
  const FeishuLoginPage({super.key});

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
      final url = await AuthFlowService.getFeishuAuthorizeUrl(
          state: buildFeishuOAuthState());
      final controller = WebViewController();
      // Web 端 webview_flutter 未实现 setJavaScriptMode，跳过即可。
      if (!kIsWeb) {
        await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      }
      controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (pageUrl) {
            if (mounted && !_returning) setState(() => _loading = true);
            _tryReturnCode(pageUrl);
          },
          onPageFinished: (_) {
            if (mounted && !_returning) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            final code = _extractOAuthCode(request.url);
            if (code != null) {
              _returnCodeToLogin(code);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (change) => _tryReturnCode(change.url),
          onWebResourceError: (err) {
            if (!mounted || _returning) return;
            setState(() {
              _error = err.description;
              _loading = false;
            });
          },
        ),
      );
      await controller.loadRequest(Uri.parse(url));
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyInitError(e);
        _loading = false;
      });
    }
  }

  String _friendlyInitError(Object e) {
    final msg = e.toString();
    final api = ApiClient.baseUrl;
    if (!kIsWeb && msg.contains('127.0.0.1')) {
      return '飞书回调地址须与 App 访问的 API 一致。\n'
          '请将 config 中 feishu.redirect_uri 设为：\n'
          'http://$api/api/auth/feishu/callback\n'
          '并在飞书开放平台添加相同重定向 URL。';
    }
    return msg;
  }

  void _tryReturnCode(String? raw) {
    final code = _extractOAuthCode(raw);
    if (code != null) _returnCodeToLogin(code);
  }

  String? _extractOAuthCode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final code = uri.queryParameters['code']?.trim();
    if (code == null || code.isEmpty) return null;
    if (uri.path.contains('/api/auth/feishu/callback') ||
        uri.queryParameters.containsKey('code')) {
      return code;
    }
    return null;
  }

  void _returnCodeToLogin(String code) {
    if (_returning || !mounted) return;
    _returning = true;
    Navigator.of(context).pop(FeishuLoginResult.authorized(code));
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
