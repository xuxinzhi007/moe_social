// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// 整页跳转到飞书授权（Web 最稳妥，避免 iframe/WebView 拦不到 callback）。
void navigateBrowserToFeishuAuthorize(String url) {
  html.window.location.assign(url);
}
