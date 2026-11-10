import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/llm_api_service.dart';
import 'package:moe_social/widgets/ai/chat_model_picker.dart';

void main() {
  testWidgets('picker lists base and derived models and reports the tap',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatModelPickerList(
            currentModel: 'qwen2.5:3b-instruct',
            models: const [
              LlmCatalogModel(
                name: 'qwen2.5:3b-instruct',
                contextLength: 8192,
              ),
              LlmCatalogModel(name: 'mine-lora', derived: true),
            ],
            onSelect: (name) => selected = name,
          ),
        ),
      ),
    ));

    expect(find.text('小主机上的模型'), findsOneWidget);
    expect(find.text('我的模型'), findsOneWidget);
    expect(find.text('qwen2.5:3b-instruct'), findsOneWidget);
    expect(find.text('mine-lora'), findsOneWidget);
    expect(find.textContaining('提示词只能看'), findsOneWidget);
    expect(find.textContaining('可以改提示词'), findsOneWidget);

    await tester.tap(find.text('mine-lora'));
    expect(selected, 'mine-lora');
  });
}
