## 1.0.0

- Stable public API.
- Add `ToolDefinition.toJsonSchema()` returning an OpenAI-style JSON schema so LLM adapters can serialise a tool definition without hand-rolling it.
- Add `InAppMcp.toolsSchemaJson()` aggregating schemas for every registered tool into `{"tools": [...]}`.
- Redesign the example app's inline tool-call card with per-tool icons, colour-coded status and policy chips, and a structured result view instead of raw JSON.
- Fix `gemma_adapter` handling of responses where Gemma 4 E2B emits unquoted JSON object keys (e.g. `{"toolName":"x","arguments":{hour:6}}`). A preprocessing pass quotes bareword keys before `ToolCallParser` runs.
- Ship companion packages `in_app_mcp_annotations` and `in_app_mcp_gen` for generating `ToolDefinition`s and typed handler adapters from annotated Dart functions.

## 0.0.2

- Expand example app with a full-screen chat experience and dedicated settings screen.
- Add inline tool-call proposal cards with manual Run/Cancel and per-tool policy visibility.
- Add Gemma adapter flow with model selection, local model catalog/status management, and tool-call parsing helpers.
- Add additional example tools (calendar, maps, email) and broaden integration/widget/parser test coverage.
- Improve runtime validation and policy/registry behavior for stricter tool argument handling.

## 0.0.1

- Initial release of `in_app_mcp` with in-app tool runtime, policy controls, registry, and method-channel scaffolding.
