import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/mcp_tool_generator.dart';

Builder mcpToolBuilder(BuilderOptions options) => PartBuilder(
  [McpToolGenerator()],
  '.mcp.g.dart',
  header:
      '// GENERATED CODE - DO NOT MODIFY BY HAND\n'
      '// ignore_for_file: type=lint',
);
