import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/post.dart';
import 'package:moe_social/pages/feed/home_feed_viewmodel.dart';

Post _post(String id) => Post(
      id: id,
      userId: 'user-$id',
      userName: '用户 $id',
      userAvatar: '',
      content: '动态 $id',
      createdAt: DateTime(2026),
    );

Map<String, dynamic> _page(List<Post> posts, int total) => {
      'posts': posts,
      'total': total,
    };

void main() {
  test('deduplicates overlapping pages by post id', () async {
    final pages = [
      _page([_post('1'), _post('2')], 3),
      _page([_post('2'), _post('3')], 3),
    ];
    var requestIndex = 0;
    final viewModel = HomeFeedViewModel(
      pageSize: 2,
      postsLoader: ({
        required page,
        required pageSize,
        viewerUserId,
        feedMode,
        topicTagId,
      }) async =>
          pages[requestIndex++],
    );
    addTearDown(viewModel.dispose);

    await viewModel.fetchPosts();
    await viewModel.loadMorePosts();

    expect(viewModel.displayPosts.map((post) => post.id), ['1', '2', '3']);
    expect(viewModel.hasMore, isFalse);
  });

  test('does not apply an outdated feed response after mode changes', () async {
    final hotResponse = Completer<Map<String, dynamic>>();
    final latestResponse = Completer<Map<String, dynamic>>();
    final viewModel = HomeFeedViewModel(
      postsLoader: ({
        required page,
        required pageSize,
        viewerUserId,
        feedMode,
        topicTagId,
      }) {
        return feedMode == 'hot' ? hotResponse.future : latestResponse.future;
      },
    );
    addTearDown(viewModel.dispose);

    final initialLoad = viewModel.fetchPosts();
    viewModel.setMode(HomeFeedMode.latest);
    hotResponse.complete(_page([_post('hot')], 1));
    await initialLoad;
    latestResponse.complete(_page([_post('latest')], 1));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.mode, HomeFeedMode.latest);
    expect(viewModel.displayPosts.map((post) => post.id), ['latest']);
  });

  test('rapid mode changes apply the latest selection and ignore stale errors',
      () async {
    final hotResponse = Completer<Map<String, dynamic>>();
    final followingResponse = Completer<Map<String, dynamic>>();
    final requestedModes = <String?>[];
    final viewModel = HomeFeedViewModel(
      postsLoader: ({
        required page,
        required pageSize,
        viewerUserId,
        feedMode,
        topicTagId,
      }) {
        requestedModes.add(feedMode);
        return feedMode == 'hot'
            ? hotResponse.future
            : followingResponse.future;
      },
    );
    addTearDown(viewModel.dispose);

    final initialLoad = viewModel.fetchPosts();
    viewModel.setMode(HomeFeedMode.latest);
    viewModel.setMode(HomeFeedMode.following);

    expect(viewModel.mode, HomeFeedMode.following);

    hotResponse.completeError(StateError('outdated hot request'));
    await initialLoad;
    await Future<void>.delayed(Duration.zero);

    expect(requestedModes, ['hot', 'following']);
    expect(viewModel.feedError, isNull);

    followingResponse.complete(_page([_post('following')], 1));
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.displayPosts.map((post) => post.id), ['following']);
    expect(viewModel.feedError, isNull);
  });
}
