## 1.0.1

- Add dartdoc comments on `mcpToolBuilder` and `McpToolGenerator`. No API changes.

## 1.0.0

- Initial public release.
- `source_gen` builder that, for every top-level function annotated with `@McpTool`, emits:
  - a matching `ToolDefinition` const with `argumentTypes` inferred from the Dart parameter types and `requiredArguments` inferred from non-defaulted non-nullable named parameters;
  - a typed `<fn>Handler(ToolCall)` adapter that casts `call.arguments` to the annotated function's named parameters, including nullable / default / `List<T>` / `Map<K, V>` handling;
  - per-file `.mcp.g.dart` part output.
- Rejects positional parameters, non-`Future<ToolResult>` returns, and unsupported parameter types with clear `InvalidGenerationSourceError` messages.
