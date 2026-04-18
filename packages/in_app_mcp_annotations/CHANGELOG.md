## 1.1.1

- Add `example/example.md` so pana's "Package has an example" check passes. No code changes.

## 1.1.0

- Add `@McpToolPreview` — mark a top-level Dart function as a side-effect-free previewer for an `@McpTool`. Pairs with the Preview hook added to `in_app_mcp` 1.1.0.
- Add `@McpToolUndo` — mark a top-level Dart function as a reverse-effect handler for an `@McpTool`. Pairs with `InAppMcp.undoFromLedger` in 1.1.0.
- Pair with [`in_app_mcp_gen`](https://pub.dev/packages/in_app_mcp_gen) ≥ 1.1.0 to generate `<fn>Previewer(ToolCall)` and `<fn>Undoer(ToolCall, ToolResult)` adapters.

## 1.0.1

- Add dartdoc comments on `@McpTool` and its fields. No API changes.

## 1.0.0

- Initial public release.
- Exports `@McpTool` — annotate a top-level Dart function to make it discoverable by [`in_app_mcp_gen`](https://pub.dev/packages/in_app_mcp_gen), which emits a matching `ToolDefinition` and typed handler adapter for the [`in_app_mcp`](https://pub.dev/packages/in_app_mcp) runtime.
- Zero runtime dependencies.
