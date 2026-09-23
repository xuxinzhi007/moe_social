import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/auth_service.dart';
import 'package:moe_social/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('profile cache replacement notifies the current-user profile listener',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'test-token',
      'user_id': 'user-1',
    });
    await AuthService.init();

    final updatedUser = User(
      id: 'user-1',
      username: '萌友',
      email: 'moe@example.com',
      avatar: 'https://example.com/avatar.png',
      createdAt: '',
      updatedAt: '',
    );

    await AuthService.replaceUserProfileCache(updatedUser);

    expect(AuthService.currentUserProfileNotifier.value, same(updatedUser));
  });
}
