import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/ai_cloud_config_service.dart';

void main() {
  test('parseAiResourceItems decodes payload_json and preserves item id', () {
    final result = parseAiResourceItems({
      'data': {
        'items': [
          {
            'id': 'agent/server-id',
            'payload_json': '{"id":"stale-id","name":"Moe","is_public":true}',
          },
        ],
      },
    });

    expect(result, [
      {
        'id': 'agent/server-id',
        'name': 'Moe',
        'is_public': true,
      },
    ]);
  });

  test('parseAiResourceItems accepts protojson payloadJson field', () {
    final result = parseAiResourceItems({
      'items': [
        {
          'id': 42,
          'payloadJson': '{"name":"Provider"}',
        },
      ],
    });

    expect(result.single, {'id': '42', 'name': 'Provider'});
  });
}
