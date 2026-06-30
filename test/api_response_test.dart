import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/api_response.dart';
import 'package:moe_social/models/user.dart';

void main() {
  test('object extracts nested data.user for GetUserInfo envelope', () {
    final json = {
      'code': 200,
      'success': true,
      'message': '操作成功',
      'data': {
        'user': {
          'id': 1,
          'username': 'xxz',
          'email': '1@163.com',
          'avatar': '/api/images/avatar.png',
          'created_at': '2024-01-01T00:00:00Z',
          'updated_at': '2024-01-01T00:00:00Z',
        },
      },
    };

    final userMap = ApiResponse.object(json, keys: const ['user']);
    final user = User.fromJson(userMap);

    expect(user.username, 'xxz');
    expect(user.email, '1@163.com');
    expect(user.id, '1');
  });

  test('object returns flat data map when it is already the target object', () {
    final json = {
      'code': 200,
      'success': true,
      'data': {
        'id': '9',
        'username': 'flat',
        'email': 'a@b.com',
      },
    };

    final map = ApiResponse.object(json, keys: const ['user']);
    expect(map['username'], 'flat');
  });
}
