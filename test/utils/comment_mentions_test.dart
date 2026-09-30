import 'package:flutter_test/flutter_test.dart';

import 'package:moe_social/utils/comment_mentions.dart';

void main() {
  test('active query only tracks an unfinished @ token', () {
    expect(activeCommentMentionQuery('hi @ali', 7), 'ali');
    expect(activeCommentMentionQuery('hi @ali ', 8), isNull);
    expect(activeCommentMentionQuery('a@b.com', 7), isNull);
    expect(activeCommentMentionQuery('@', 1), '');
  });

  test('apply mention replaces the active token', () {
    final edit = applyCommentMention('看 @al', 5, 'alice');
    expect(edit.text, '看 @alice ');
    expect(edit.cursor, '看 @alice '.length);
  });
}
