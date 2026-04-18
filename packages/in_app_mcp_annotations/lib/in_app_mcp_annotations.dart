/// Annotations consumed by [`in_app_mcp_gen`](https://pub.dev/packages/in_app_mcp_gen)
/// to generate `ToolDefinition`s and typed handler adapters for the
/// [`in_app_mcp`](https://pub.dev/packages/in_app_mcp) runtime.
///
/// This package defines declarative annotations only. It carries no runtime
/// dependencies and emits no code on its own — pair it with `in_app_mcp_gen`
/// as a `dev_dependency` to produce the generated artefacts.
///
/// ```dart
/// import 'package:in_app_mcp/in_app_mcp.dart';
/// import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';
///
/// part 'my_tools.mcp.g.dart';
///
/// @McpTool(description: 'Echo a message back.')
/// Future<ToolResult> echo({required String message}) async {
///   return ToolResult.ok('ok', data: {'echo': message});
/// }
/// ```
library;

/// Marks a top-level Dart function as an `in_app_mcp` tool.
///
/// When `in_app_mcp_gen` runs, it emits a `<fn>Definition` constant and a
/// typed `<fn>Handler(ToolCall)` adapter for every function annotated with
/// `@McpTool`.
///
/// - [description] — human-readable description exposed to the LLM and UI.
/// - [name] — overrides the derived tool name (snake_case of the function
///   name by default).
/// - [allowAdditionalArguments] — if `true`, unknown keys in the caller's
///   arguments are accepted. Defaults to `false` (strict).
class McpTool {
  /// Creates an [McpTool] annotation.
  const McpTool({
    this.name,
    required this.description,
    this.allowAdditionalArguments = false,
  });

  /// Explicit tool name. If omitted, the generator derives one from the
  /// annotated function's name (camelCase → snake_case).
  final String? name;

  /// Human-readable description. Rendered in the inline tool-call UI and
  /// included in the JSON schema passed to LLM adapters.
  final String description;

  /// Forwarded verbatim to `ToolDefinition.allowAdditionalArguments` on
  /// the generated definition. Defaults to `false` here (stricter than the
  /// core's `true`) because an annotated function's parameter list is
  /// expected to be exhaustive.
  final bool allowAdditionalArguments;
}
