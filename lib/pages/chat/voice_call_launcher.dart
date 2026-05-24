import 'package:flutter/material.dart';

import '../../app/deferred_route.dart';
import 'voice_call_page.dart' deferred as voice_call;

/// Opens [VoiceCallPage] with deferred loading so Agora is not in the main bundle.
Future<void> openVoiceCallPage(
  BuildContext context, {
  required String channelName,
  required String userName,
  required String userAvatar,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => DeferredRoute(
        loadLibrary: voice_call.loadLibrary,
        message: '正在加载通话模块…',
        builder: () => voice_call.VoiceCallPage(
          channelName: channelName,
          userName: userName,
          userAvatar: userAvatar,
        ),
      ),
    ),
  );
}

/// Replaces the current route with [VoiceCallPage] (e.g. incoming call accept).
Future<void> replaceWithVoiceCallPage(
  BuildContext context, {
  required String channelName,
  required String userName,
  required String userAvatar,
}) {
  return Navigator.of(context).pushReplacement<void, void>(
    MaterialPageRoute<void>(
      builder: (context) => DeferredRoute(
        loadLibrary: voice_call.loadLibrary,
        message: '正在加载通话模块…',
        builder: () => voice_call.VoiceCallPage(
          channelName: channelName,
          userName: userName,
          userAvatar: userAvatar,
        ),
      ),
    ),
  );
}
