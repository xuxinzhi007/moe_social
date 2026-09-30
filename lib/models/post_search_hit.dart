import '../utils/api_json.dart';

/// `/api/posts/search` 的一条命中，只含打开详情所需的摘要。
class PostSearchHit {
  const PostSearchHit({
    required this.postId,
    required this.userId,
    required this.userName,
    required this.snippet,
    this.likes = 0,
    this.comments = 0,
  });

  final String postId;
  final String userId;
  final String userName;
  final String snippet;
  final int likes;
  final int comments;

  factory PostSearchHit.fromJson(Map<String, dynamic> json) {
    final snippet = apiString(json, 'snippet', 'snippet');
    final content = apiString(json, 'content', 'content');
    return PostSearchHit(
      postId: apiString(json, 'post_id', 'postId'),
      userId: apiString(json, 'user_id', 'userId'),
      userName: apiString(json, 'user_name', 'userName', fallback: '用户'),
      snippet: snippet.isNotEmpty ? snippet : content,
      likes: apiInt(apiField(json, 'likes', 'likes')),
      comments: apiInt(apiField(json, 'comments', 'comments')),
    );
  }
}
