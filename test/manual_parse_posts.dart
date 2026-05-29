import 'dart:convert';
import 'dart:io';

import 'package:moe_social/models/post.dart';
import 'package:moe_social/services/api_response.dart';

void main() {
  final path = Platform.environment['POSTS_JSON'] ?? '/tmp/hot_posts.json';
  final result =
      json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
  final postsJson = ApiResponse.listOf(result, keys: const ['posts']);
  stdout.writeln('count ${postsJson.length}');
  stdout.writeln('ids ${postsJson.map((j) => j['id']).toList()}');
  var i = 0;
  for (final raw in postsJson) {
    try {
      final map = Map<String, dynamic>.from(raw as Map);
      final p = Post.fromJson(map);
      stdout.writeln('ok $i id=${p.id} user=${p.userName}');
    } catch (e, st) {
      stdout.writeln('FAIL $i $e');
      stdout.writeln(st);
    }
    i++;
  }
}
