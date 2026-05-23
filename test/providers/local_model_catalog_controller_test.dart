import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/providers/local_model_catalog_controller.dart';

void main() {
  test('LocalModelCatalogController loads builtin catalog synchronously', () {
    final controller = LocalModelCatalogController();
    expect(controller.hasCatalog, isTrue);
    expect(controller.catalog.length, 3);
    expect(
      controller.catalog.any((e) => e.name.contains('Qwen2.5 0.5B')),
      isTrue,
    );
    expect(controller.syncing, isFalse);
    expect(controller.error, isNull);
  });
}
