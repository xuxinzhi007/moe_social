import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/ai_message_format_parser.dart';
import 'package:moe_social/widgets/ai/ai_draw_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('parseAiMessageContent extracts closed and unclosed <draw> blocks', () {
    const raw =
        '好呀，这就给你画一张～\n<draw>a cute anime cat under cherry blossoms, soft lighting, 8k</draw>';
    final blocks = parseAiMessageContent(raw);

    expect(blocks.length, 2);
    expect(blocks[0].kind, AiMessageBlockKind.text);
    expect(blocks[0].content, '好呀，这就给你画一张～');
    expect(blocks[1].kind, AiMessageBlockKind.draw);
    expect(blocks[1].isIncomplete, isFalse);
    expect(
      blocks[1].content,
      'a cute anime cat under cherry blossoms, soft lighting, 8k',
    );
  });

  test(
      'parseAiMessageContent tolerates 3b model (draw) loose syntax and strips 【置顶】',
      () {
    const raw =
        '小星没实体照片，但我可以描述一个场景给你。【置顶】\n(draw)一个温和的灯光下，小星静静地坐在窗边，手中握着一本书，窗外是宁静的夜色。';
    final blocks = parseAiMessageContent(raw);

    expect(blocks.length, 2);
    expect(blocks[0].kind, AiMessageBlockKind.text);
    expect(blocks[0].content, '小星没实体照片，但我可以描述一个场景给你。');
    expect(blocks[1].kind, AiMessageBlockKind.draw);
    expect(
      blocks[1].content,
      '一个温和的灯光下，小星静静地坐在窗边，手中握着一本书，窗外是宁静的夜色。',
    );
  });

  test('parseAiMessageContent marks streaming <draw> block as incomplete', () {
    const streaming = '等我一下哦\n<draw>cinematic portrait, sunset';
    final blocks = parseAiMessageContent(streaming);

    expect(blocks.length, 2);
    expect(blocks[1].kind, AiMessageBlockKind.draw);
    expect(blocks[1].isIncomplete, isTrue);
    expect(blocks[1].content, 'cinematic portrait, sunset');
  });

  test(
      'plainTextForSpeech strips <draw> and (draw) prompt so TTS only reads the reply',
      () {
    const raw = '我画好啦！【置顶】\n(draw)1girl, smile, masterpiece';
    expect(plainTextForSpeech(raw), '我画好啦！');
  });

  testWidgets('AiDrawCard shows drafting banner while <draw> is streaming',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiDrawCard(
            prompt: 'cyberpunk street, neon rain',
            isIncomplete: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('正在编写提示词'), findsOneWidget);
  });

  testWidgets(
      'AiDrawCard shows manual B button for uncached history without firing ComfyUI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiDrawCard(
            prompt: 'historical prompt without cache',
            isIncomplete: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 绘画提示词已就绪'), findsOneWidget);
    expect(find.text('生成图片'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
  });
}
