import 'package:flutter/material.dart';

import '../models/post.dart';

/// 与 [MaterialApp] 中注册的 `/post-detail` 一致：完整动态 + 评论区，返回值为评论条数 [int]（若用户直接返回则可能为 null）。
Future<int?> openPostDetail(BuildContext context, Post post) async {
  final result = await Navigator.pushNamed<Object?>(
    context,
    '/post-detail',
    arguments: <String, Object?>{
      'postId': post.id,
      'post': post,
    },
  );
  if (result is int) return result;
  return null;
}
