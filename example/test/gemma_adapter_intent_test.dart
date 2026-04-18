import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp_example/llm/gemma_adapter.dart';

void main() {
  test('adapter id uses model file name', () {
    expect(
      GemmaAdapter.adapterIdForPath('/tmp/models/gemma-4-E2B-it.litertlm'),
      'gemma4:gemma-4-E2B-it.litertlm',
    );
  });

  test('adapter id falls back for empty path', () {
    expect(GemmaAdapter.adapterIdForPath('  '), 'gemma4');
  });
}
