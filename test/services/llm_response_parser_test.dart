import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/services/llm_response_parser.dart';

String parse(String text, {bool terminal = true}) =>
    LlmResponseParser.extractChatContent(
        LlmResponseParser.decodeJsonOrNdjson(text),
        terminalMode: terminal);

void main() {
  test('wrapped content stays compatible with nested platform envelope', () {
    expect(
        parse('{"code":0,"data":{"code":0,"success":true,"content":"你好"}}',
            terminal: false),
        '你好');
  });
  test('Ollama ordinary and complete NDJSON responses', () {
    expect(parse('{"message":{"content":"hello"},"done":true}'), 'hello');
    expect(
        parse(
            '{"message":{"content":"hel"},"done":false}\n{"message":{"content":"lo"},"done":true}'),
        'hello');
  });
  test('OpenAI ordinary response supports string and text parts', () {
    expect(parse('{"choices":[{"message":{"content":"hello"}}]}'), 'hello');
    expect(
        parse(
            '{"choices":[{"message":{"content":[{"type":"text","text":"hello"}]}}]}'),
        'hello');
  });
  test('OpenAI SSE chunks and DONE are understood', () {
    expect(
        parse(
            'data: {"choices":[{"delta":{"content":"hi"}}]}\n\ndata: [DONE]\n'),
        'hi');
  });
  for (final raw in [
    '{"message":{"content":"partial"},"done":false}\n{"error":"offline"}',
    '{"message":{"content":"partial"},"done":false}',
    '{"message":{"content":"partial"}}\n{"message":{"content":"incomplete"}}',
    '{"message":{"content":"partial"},"done":false}\ninvalid-json',
    'data: {"choices":[{"delta":{"content":"partial"}}]}\ndata: {"error":{"message":"offline"}}\ndata: [DONE]',
    '{"choices":[{"message":{"content":"partial"}}],"error":{"message":"failed"}}',
    '{"code":0,"data":{"success":false,"message":"failed","content":"partial"}}',
  ]) {
    test('partial content does not hide stream or envelope failure: $raw', () {
      expect(() => parse(raw), throwsFormatException);
    });
  }
}
