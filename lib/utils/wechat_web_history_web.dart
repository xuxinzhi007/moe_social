// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void clearWechatCodeFromBrowserUrl() {
  final base = Uri.parse(html.window.location.href);
  final next = base.replace(queryParameters: {});
  html.window.history.replaceState(null, '', next.toString());
}
