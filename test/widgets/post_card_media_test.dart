import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/hand_draw_card.dart';
import 'package:moe_social/models/post.dart';
import 'package:moe_social/theme/moe_tokens.dart';
import 'package:moe_social/widgets/post_card.dart';

Post _post({List<String> images = const ['https://example.com/post.jpg']}) {
  return Post(
    id: 'post-media-test',
    userId: 'user-media-test',
    userName: '测试用户',
    userAvatar: '',
    content: '一段用于验证动态媒体密度的正文。',
    images: images,
    createdAt: DateTime(2026, 8, 30),
  );
}

Post _handDrawPost() {
  return Post(
    id: 'post-hand-draw-test',
    userId: 'user-media-test',
    userName: '测试用户',
    userAvatar: '',
    content: '一条带手绘媒体的动态。',
    handDrawCardJson: jsonEncode(
      HandDrawCardData(strokes: const []).toJson(),
    ),
    createdAt: DateTime(2026, 8, 30),
  );
}

Widget _host(PostCard child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('feed single image preview stays compact', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(PostCard(post: _post())));
    await tester.pump();

    final media =
        find.byKey(const ValueKey('post_media_post-media-test_single'));
    expect(media, findsOneWidget);
    final size = tester.getSize(media);
    expect(
      size.height,
      lessThanOrEqualTo(MoeTokens.postMediaFeedMaxHeight),
    );
    expect(
      size.width / size.height,
      closeTo(MoeTokens.postMediaFeedAspectRatio, 0.02),
    );
  });

  testWidgets('detail single image preview has a separate upper bound',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post(),
          mediaPresentation: PostCardMediaPresentation.detail,
        ),
      ),
    );
    await tester.pump();

    final media =
        find.byKey(const ValueKey('post_media_post-media-test_single'));
    expect(media, findsOneWidget);
    final size = tester.getSize(media);
    expect(
      size.height,
      lessThanOrEqualTo(MoeTokens.postMediaDetailMaxHeight),
    );
    expect(
      size.width / size.height,
      closeTo(MoeTokens.postMediaDetailAspectRatio, 0.02),
    );
  });

  testWidgets('feed multi-image grid stays within the feed height budget',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        PostCard(
          post: _post(
            images: const [
              'https://example.com/1.jpg',
              'https://example.com/2.jpg',
              'https://example.com/3.jpg',
              'https://example.com/4.jpg',
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final media = find.byKey(const ValueKey('post_media_post-media-test_grid'));
    expect(media, findsOneWidget);
    expect(
      tester.getSize(media).height,
      lessThanOrEqualTo(MoeTokens.postMediaFeedGridMaxHeight),
    );
  });

  testWidgets('hand-draw preview uses the same compact landscape window',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(PostCard(post: _handDrawPost())));
    await tester.pump();

    final media =
        find.byKey(const ValueKey('post_media_post-hand-draw-test_hand_draw'));
    expect(media, findsOneWidget);
    final size = tester.getSize(media);
    expect(size.height, lessThanOrEqualTo(MoeTokens.postMediaFeedMaxHeight));
    expect(size.width, greaterThan(size.height));
  });
}
