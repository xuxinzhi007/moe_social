import 'package:flutter_test/flutter_test.dart';

import 'package:moe_social/models/reply_assist_models.dart';

void main() {
  test('ReplyAssistSuggestResult parses judge and options', () {
    final result = ReplyAssistSuggestResult.fromJson({
      'judge': {
        'intent': '问候',
        'emotion': '平和',
        'urgency': '低',
        'reply_stance': '正常回应',
        'should_reply': 'reply',
      },
      'options': [
        {'label': '稳妥', 'text': '你好呀'},
        {'label': '推进', 'text': '刚看到消息'},
        {'label': '轻松', 'text': '哈哈在呢'},
      ],
      'session_id': 'abc',
    });
    expect(result.judge.intent, '问候');
    expect(result.options.length, 3);
    expect(result.options.first.text, '你好呀');
  });
}
