import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/widgets/like_button.dart';

void main() {
  testWidgets('exposes the like state and count to accessibility', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LikeButton(
                postId: 'post-1',
                userId: 'user-1',
                isLiked: false,
                likeCount: 12,
              ),
            ),
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      final likeSemantics = tester.getSemantics(find.bySemanticsLabel('点赞'));
      expect(
        likeSemantics,
        matchesSemantics(
          label: '点赞',
          value: '12',
          isButton: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('fits a narrow action area with a multi-digit count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 88,
              child: LikeButton(
                postId: 'post-1',
                userId: 'user-1',
                isLiked: true,
                likeCount: 12345,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
