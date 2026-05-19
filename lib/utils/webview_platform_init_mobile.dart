import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void ensureWebViewPlatformInitialized() {
  if (WebViewPlatform.instance != null) {
    return;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      WebViewPlatform.instance = AndroidWebViewPlatform();
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      WebViewPlatform.instance = WebKitWebViewPlatform();
    default:
      break;
  }
}
