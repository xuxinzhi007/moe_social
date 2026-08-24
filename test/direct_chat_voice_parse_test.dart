import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/chat/direct_chat_viewmodel.dart';

/// [DirectChatViewModel.voiceInfoOf] 的 `[VOICE]` 消息解析防御测试。
void main() {
  final vm = DirectChatViewModel(peerUserId: 'peer');

  group('voiceInfoOf', () {
    test('无分隔符的字面文本返回 null', () {
      expect(vm.voiceInfoOf('[VOICE]hello'), isNull);
    });

    test('URL 含 | 时取最后一个分隔符正确解析', () {
      final info = vm.voiceInfoOf('[VOICE]http://x/api/images/a|b.m4a|7');
      expect(info, isNotNull);
      final (url, duration) = info!;
      // url 部分应保留完整的 `a|b.m4a` 文件名，不被首个 `|` 截断。
      expect(url, contains('/api/images/a'));
      expect(url, contains('b.m4a'));
      expect(duration, 7);
    });

    test('正常格式返回正确 url 与 duration', () {
      final info = vm.voiceInfoOf('[VOICE]http://x/api/images/a__b.m4a|5');
      expect(info, isNotNull);
      final (url, duration) = info!;
      // resolveMediaUrl 会把 /api/images/ 的 host 重写为当前 API base，
      // 这里只断言路径部分稳定。
      expect(url, endsWith('/api/images/a__b.m4a'));
      expect(duration, 5);
    });
  });
}
