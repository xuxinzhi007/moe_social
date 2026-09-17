// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// 三个函数都不吞异常：隐私模式下 sessionStorage 可能直接拒绝访问，
// 写入也可能因配额失败。这些必须让授权中止，而不是静默降级成
// 「没有待处理事务」—— 那样用户走完授权后才会莫名失败。

String? readOauthSessionItem(String key) => html.window.sessionStorage[key];

void writeOauthSessionItem(String key, String value) {
  html.window.sessionStorage[key] = value;
}

void removeOauthSessionItem(String key) =>
    html.window.sessionStorage.remove(key);
