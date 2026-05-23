import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/ai/local_model_manager_page.dart';

void main() {
  testWidgets('LocalModelManagerPage shows builtin catalog', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LocalModelManagerPage()),
    );
    await tester.pump();
    expect(find.text('离线模型'), findsOneWidget);
    expect(find.text('Qwen2.5 0.5B 极速'), findsOneWidget);
    expect(find.text('可下载'), findsOneWidget);
    expect(find.textContaining('Hugging Face'), findsWidgets);
  });
}
