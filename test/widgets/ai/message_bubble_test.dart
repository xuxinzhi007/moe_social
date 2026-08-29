import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/widgets/ai/message_bubble.dart';

void main() {
  testWidgets('error bubble exposes recovery copy and action', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AiMessageBubble(
            content: '模型服务调用失败，请检查 API Key、模型和额度后重试。',
            contentType: MessageContentType.text,
            isUser: false,
            airyCompanion: true,
            isError: true,
            onErrorAction: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('回复没有送达'), findsOneWidget);
    expect(
      find.text('模型服务调用失败，请检查 API Key、模型和额度后重试。'),
      findsOneWidget,
    );
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });
}
