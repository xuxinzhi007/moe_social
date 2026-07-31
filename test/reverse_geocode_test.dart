import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/utils/reverse_geocode.dart';

void main() {
  test('Beijing coordinates map to 北京市 fallback', () {
    expect(
      ReverseGeocode.approximateChinaLabel(39.915001, 116.403999),
      '北京市',
    );
  });

  test('Shanghai coordinates map to 上海市', () {
    expect(
      ReverseGeocode.approximateChinaLabel(31.2304, 121.4737),
      '上海市',
    );
  });

  test('outside China returns null', () {
    expect(
      ReverseGeocode.approximateChinaLabel(40.7128, -74.0060),
      isNull,
    );
  });
}
