import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/autoglm/autoglm_unavailable_page.dart';

void main() {
  testWidgets('deep-linked AutoGLM shows unregistered copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AutoglmUnavailablePage()),
    );

    expect(find.text('服务未注册·不可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
