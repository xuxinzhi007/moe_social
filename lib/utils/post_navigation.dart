import 'package:flutter/material.dart';

import '../models/post.dart';

/// 与 [MaterialApp] 中注册的 `/post-detail` 一致：完整动态 + 评论区，返回值为评论条数 [int]（若用户直接返回则可能为 null）。
Future<T?> openPostDetail<T>(BuildContext context, Post post) {
  return Navigator.pushNamed<T>(
    context,
    '/post-detail',
    arguments: <String, Object?>{
      'postId': post.id,
      'post': post,
    },
  );
}
