import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/providers/virtual_avatar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy community float stays hidden even if old pref is on', () async {
    SharedPreferences.setMockInitialValues({
      'virtual_avatar_enabled': true,
    });
    final provider = VirtualAvatarProvider();
    await provider.init();
    expect(provider.enabled, isTrue);
    expect(provider.isVisible, isFalse);
  });
}
