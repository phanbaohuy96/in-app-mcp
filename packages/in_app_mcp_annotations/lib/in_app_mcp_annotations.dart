/// Annotations consumed by `in_app_mcp_gen` to produce `ToolDefinition`
/// and typed handler adapters for `in_app_mcp`.
library;

class McpTool {
  const McpTool({
    this.name,
    required this.description,
    this.allowAdditionalArguments = false,
  });

  final String? name;
  final String description;
  final bool allowAdditionalArguments;
}
