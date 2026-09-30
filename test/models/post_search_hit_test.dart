import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/post_search_hit.dart';

void main() {
  test('兼容蛇形和驼峰字段，摘要为空时回退正文', () {
    final snake = PostSearchHit.fromJson({
      'post_id': '12',
      'user_id': '3',
      'user_name': 'XXZ',
      'snippet': '冰咖啡',
      'likes': 2,
      'comments': '1',
    });
    expect(snake.postId, '12');
    expect(snake.userName, 'XXZ');
    expect(snake.snippet, '冰咖啡');
    expect(snake.likes, 2);
    expect(snake.comments, 1);

    final camel = PostSearchHit.fromJson({
      'postId': '9',
      'userId': '4',
      'userName': '啾啾',
      'content': '正文回退',
    });
    expect(camel.postId, '9');
    expect(camel.snippet, '正文回退');
    expect(camel.userName, '啾啾');
  });
}
