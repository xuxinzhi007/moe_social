import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/widgets/ai/companion_attention_sheet.dart';

void main() {
  testWidgets('attention bubble renders non-blocking banner and returns true on tap',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await CompanionAttentionSheet.show(
                    context,
                    greeting: '今晚早点休息哦～',
                    sourceLabel: '刚刚收到的主动回访',
                  );
                },
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('TA 想你了 · 刚刚收到的主动回访'), findsOneWidget);
    expect(find.text('今晚早点休息哦～'), findsOneWidget);
    expect(find.text('去聊聊'), findsOneWidget);

    await tester.tap(find.text('去聊聊'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('今晚早点休息哦～'), findsNothing);
  });

  testWidgets('attention bubble returns false when dismissed by close button',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await CompanionAttentionSheet.show(
                    context,
                    greeting: '在忙什么呢？',
                  );
                },
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('在忙什么呢？'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text('在忙什么呢？'), findsNothing);
  });
}
