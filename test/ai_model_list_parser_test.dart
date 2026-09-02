import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/ai_model_list_parser.dart';

void main() {
  test('parses the standard OpenAI data list', () {
    final models = AiModelListParser.extract({
      'object': 'list',
      'data': [
        {'id': 'gpt-4o', 'object': 'model'},
        {'id': 'gpt-4o-mini', 'object': 'model'},
      ],
    });

    expect(models, ['gpt-4o', 'gpt-4o-mini']);
  });

  test('supports Ollama-style names and removes duplicates', () {
    final models = AiModelListParser.extract({
      'models': [
        {'name': 'llama3.1'},
        {'name': 'llama3.1'},
        {'model': 'qwen2.5'},
      ],
    });

    expect(models, ['llama3.1', 'qwen2.5']);
  });

  test('supports nested data models and string lists', () {
    final models = AiModelListParser.extract({
      'data': {
        'models': ['deepseek-chat', ' deepseek-reasoner '],
      },
    });

    expect(models, ['deepseek-chat', 'deepseek-reasoner']);
  });
}
