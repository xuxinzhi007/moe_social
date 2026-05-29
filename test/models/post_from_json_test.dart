import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/post.dart';

void main() {
  group('Post.fromJson', () {
    test('parses Kratos protojson camelCase fields', () {
      final post = Post.fromJson({
        'id': '45',
        'userId': '6',
        'userName': 'wx_bFAPVQ',
        'userAvatar': 'https://example.com/avatar.png',
        'content': '回家',
        'createdAt': '2026-05-28 20:12:31',
        'handDrawCard': '{"v":1}',
        'isLiked': false,
        'likes': 2,
        'comments': 14,
      });

      expect(post.id, '45');
      expect(post.userId, '6');
      expect(post.userName, 'wx_bFAPVQ');
      expect(post.userAvatar, 'https://example.com/avatar.png');
      expect(post.content, '回家');
      expect(post.likes, 2);
      expect(post.comments, 14);
      expect(post.isLiked, isFalse);
      expect(post.handDrawCardJson, '{"v":1}');
      expect(post.createdAt.year, 2026);
      expect(post.createdAt.month, 5);
      expect(post.createdAt.day, 28);
    });

    test('parses legacy snake_case fields', () {
      final post = Post.fromJson({
        'id': '1',
        'user_id': '2',
        'user_name': 'legacy_user',
        'user_avatar': 'https://example.com/a.png',
        'content': 'hi',
        'created_at': '2026-01-15 10:00:00',
        'is_liked': true,
      });

      expect(post.userName, 'legacy_user');
      expect(post.userId, '2');
      expect(post.isLiked, isTrue);
    });
  });
}
