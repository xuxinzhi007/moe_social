import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/pages/gallery/cloud_image_viewer_page.dart';

void main() {
  test('parses media size from proto JSON int64 strings and legacy numbers',
      () {
    expect(parseCloudImageSize('1048576'), 1048576);
    expect(parseCloudImageSize(2048), 2048);
    expect(parseCloudImageSize(512.9), 512);
  });

  test('treats malformed media size as unavailable', () {
    expect(parseCloudImageSize('not-a-number'), isNull);
    expect(parseCloudImageSize(null), isNull);
  });
}
