## 1.1.0

- Add `McpToolPreviewGenerator` — for every `@McpToolPreview`-annotated top-level function returning `Future<Preview>`, emits a `<fn>Previewer(ToolCall)` adapter that unmarshals typed named parameters from `call.arguments`.
- Add `McpToolUndoGenerator` — for every `@McpToolUndo`-annotated function returning `Future<ToolResult>`, emits a `<fn>Undoer(ToolCall, ToolResult)` adapter.
- Share parameter-parsing + type-casting helpers across the three generators.
- Bump minimum `in_app_mcp_annotations` to `^1.1.0` for `@McpToolPreview` / `@McpToolUndo` support.

## 1.0.1

- Add dartdoc comments on `mcpToolBuilder` and `McpToolGenerator`. No API changes.

## 1.0.0

- Initial public release.
- `source_gen` builder that, for every top-level function annotated with `@McpTool`, emits:
  - a matching `ToolDefinition` const with `argumentTypes` inferred from the Dart parameter types and `requiredArguments` inferred from non-defaulted non-nullable named parameters;
  - a typed `<fn>Handler(ToolCall)` adapter that casts `call.arguments` to the annotated function's named parameters, including nullable / default / `List<T>` / `Map<K, V>` handling;
  - per-file `.mcp.g.dart` part output.
- Rejects positional parameters, non-`Future<ToolResult>` returns, and unsupported parameter types with clear `InvalidGenerationSourceError` messages.
