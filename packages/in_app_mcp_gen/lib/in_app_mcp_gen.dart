/// Build-runner code generator for
/// [`in_app_mcp`](https://pub.dev/packages/in_app_mcp).
///
/// Every top-level function annotated with `@McpTool` from
/// [`in_app_mcp_annotations`](https://pub.dev/packages/in_app_mcp_annotations)
/// yields a matching `ToolDefinition` constant and a typed
/// `<fn>Handler(ToolCall)` adapter, written to a sibling
/// `*.mcp.g.dart` part file.
///
/// See the package README for setup + usage. The public entry point is
/// [mcpToolBuilder], referenced from `build.yaml` in the consuming app.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/mcp_tool_generator.dart';

/// Factory used by `build_runner` to register the `@McpTool` generator.
///
/// Produces a [PartBuilder] that writes each annotated library's output to
/// a `*.mcp.g.dart` part file. The emitted header disables lints inside
/// the generated code so host projects with strict analysis configs don't
/// flag machine-generated casts.
Builder mcpToolBuilder(BuilderOptions options) => PartBuilder(
  [McpToolGenerator()],
  '.mcp.g.dart',
  header:
      '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
      '// ignore_for_file: type=lint',
);
