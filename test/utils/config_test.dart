import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/config.dart';

void main() {
  test('uses the manually selected API environment', () {
    expect(AppConfig.isProduction, isFalse);
    expect(AppConfig.baseUrl, AppConfig.developmentUrl);
  });
}
