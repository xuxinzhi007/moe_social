import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/widgets/ai/ai_draw_card.dart';
import 'package:moe_social/widgets/ai/ai_rich_message_body.dart';
import 'package:moe_social/widgets/ai/message_bubble.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets(
      'assistant message with text and <draw> splits into separate text bubble and standalone media card',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiMessageBubble(
            content:
                '小星没实体照片，但我可以描述一个场景给你。\n<draw>1girl, warm lamp light, reading book</draw>',
            contentType: MessageContentType.text,
            isUser: false,
            richFormat: true,
            airyCompanion: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小星没实体照片，但我可以描述一个场景给你。'), findsOneWidget);
    expect(find.byType(AiDrawCard), findsOneWidget);
    // AiDrawCard is rendered as a standalone media row, not nested inside AiRichMessageBody's text bubble.
    expect(
      find.descendant(
        of: find.byType(AiRichMessageBody),
        matching: find.byType(AiDrawCard),
      ),
      findsNothing,
    );
  });
}
