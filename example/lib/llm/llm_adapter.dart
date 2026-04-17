import 'package:in_app_mcp/in_app_mcp.dart';

abstract interface class LlmAdapter {
  Future<ToolCall> buildToolCall(String userPrompt);
}
