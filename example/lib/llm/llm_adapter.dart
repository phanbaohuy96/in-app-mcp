import 'package:in_app_mcp/in_app_mcp.dart';

import 'llm_adapter_mode.dart';

class LlmTurn {
  const LlmTurn({required this.message, this.toolCall});

  final String message;
  final ToolCall? toolCall;
}

abstract class LlmAdapter {
  LlmAdapterMode get mode;

  String get id;

  Future<LlmTurn> buildTurn(String userPrompt);

  Future<void> dispose() async {}
}
