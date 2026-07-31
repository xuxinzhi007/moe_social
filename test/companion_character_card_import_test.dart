import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/companion_character_card_import.dart';

void main() {
  group('CompanionCharacterCardImport', () {
    test('parses SillyTavern V2 JSON', () {
      final draft = CompanionCharacterCardImport.fromJsonString(jsonEncode({
        'spec': 'chara_card_v2',
        'spec_version': '2.0',
        'data': {
          'name': '阿悠',
          'description': '温柔的陪伴者',
          'personality': '温暖, 好奇',
          'scenario': '傍晚的窗边',
          'system_prompt': '用简短口语回复',
          'first_mes': '嗨，今天过得怎么样？',
          'mes_example': '{{user}}: 你好\n{{char}}: 嗯嗯～',
          'tags': ['陪伴', '温柔'],
          'character_book': {'entries': []},
        },
      }));

      expect(draft.name, '阿悠');
      expect(draft.persona, contains('温柔的陪伴者'));
      expect(draft.persona, contains('性格：温暖, 好奇'));
      expect(draft.persona, contains('场景：傍晚的窗边'));
      expect(draft.personalityTraits, ['陪伴', '温柔']);
      expect(draft.systemPromptOverride, contains('用简短口语回复'));
      expect(draft.systemPromptOverride, contains('[开场白参考]'));
      expect(draft.systemPromptOverride, contains('[对话示例]'));
      expect(draft.sourceLabel, 'SillyTavern V2');
      expect(
        draft.notices.any((n) => n.contains('Character Book')),
        isTrue,
      );
    });

    test('parses flat TavernAI-style JSON', () {
      final draft = CompanionCharacterCardImport.fromJsonString(jsonEncode({
        'name': '小猫',
        'description': '爱撒娇',
        'personality': '俏皮',
        'system_prompt': '喵一下',
      }));

      expect(draft.name, '小猫');
      expect(draft.persona, contains('爱撒娇'));
      expect(draft.systemPromptOverride, '喵一下');
      expect(draft.sourceLabel, 'SillyTavern / TavernAI');
    });

    test('parses Moe Social export card and skips lorebook', () {
      final draft = CompanionCharacterCardImport.fromJsonString(jsonEncode({
        'card_type': 'moe_social_character_card',
        'version': 2,
        'agent': {
          'name': 'Moe卡',
          'description': '简介',
          'persona': '细心',
          'scenario': '咖啡馆',
          'system_prompt': '保持轻声',
          'opening_message': '欢迎光临',
          'example_dialogues': 'A: hi\nB: hello',
        },
        'lorebook': {
          'name': '世界',
          'entries': [
            {'title': 'x', 'content': 'y'},
          ],
        },
      }));

      expect(draft.name, 'Moe卡');
      expect(draft.persona, contains('简介'));
      expect(draft.persona, contains('性格：细心'));
      expect(draft.sourceLabel, 'Moe Social 角色卡');
      expect(draft.notices.any((n) => n.contains('Lorebook')), isTrue);
    });

    test('extracts chara from PNG tEXt chunk', () {
      final cardJson = jsonEncode({
        'spec': 'chara_card_v2',
        'data': {
          'name': 'PNG角色',
          'description': '来自图片卡',
          'personality': '沉静',
        },
      });
      final png = _buildPngWithChara(cardJson);
      final draft = CompanionCharacterCardImport.fromBytes(png);

      expect(draft.name, 'PNG角色');
      expect(draft.persona, contains('来自图片卡'));
      expect(draft.avatarPngBytes, isNotNull);
      expect(draft.sourceLabel, 'SillyTavern PNG');
    });

    test('rejects empty JSON', () {
      expect(
        () => CompanionCharacterCardImport.fromJsonString('   '),
        throwsA(isA<Exception>()),
      );
    });
  });
}

/// 最小合法 PNG（1x1 IHDR + tEXt chara + IEND），供单测。
Uint8List _buildPngWithChara(String json) {
  final signature = Uint8List.fromList(
    [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
  );
  // IHDR for 1x1 RGBA
  final ihdrData = Uint8List.fromList([
    0, 0, 0, 1, // width
    0, 0, 0, 1, // height
    8, // bit depth
    6, // color type RGBA
    0, 0, 0, // compression, filter, interlace
  ]);
  final ihdr = _pngChunk('IHDR', ihdrData);

  final b64 = base64.encode(utf8.encode(json));
  final textBytes = <int>[
    ...utf8.encode('chara'),
    0,
    ...utf8.encode(b64),
  ];
  final text = _pngChunk('tEXt', Uint8List.fromList(textBytes));
  final iend = _pngChunk('IEND', Uint8List(0));

  return Uint8List.fromList([...signature, ...ihdr, ...text, ...iend]);
}

Uint8List _pngChunk(String type, Uint8List data) {
  final typeBytes = utf8.encode(type);
  final len = ByteData(4)..setUint32(0, data.length);
  final crcInput = Uint8List.fromList([...typeBytes, ...data]);
  final crc = ByteData(4)..setUint32(0, _crc32(crcInput));
  return Uint8List.fromList([
    ...len.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List(),
  ]);
}

int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
