import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/widgets/like_button.dart';
import 'package:moe_social/widgets/moe_like_action_button.dart';

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
          hasEnabledState: true,
          isEnabled: true,
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

  testWidgets('ignores repeated taps while the like request is pending', (
    tester,
  ) async {
    final requests = <Completer<void>>[];
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: MoeLikeActionButton(
              isLiked: false,
              likeCount: 0,
              onPressed: () {
                calls++;
                final request = Completer<void>();
                requests.add(request);
                return request.future;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    requests.single.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    expect(calls, 2);

    requests.last.complete();
    await tester.pumpAndSettle();
  });
}
