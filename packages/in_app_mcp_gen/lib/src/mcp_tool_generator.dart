// source_gen 2.x still surfaces the legacy Element API in
// GeneratorForAnnotation. Suppress the migration notices here rather than
// migrating the whole generator to the Element2 model.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:in_app_mcp_annotations/in_app_mcp_annotations.dart';
import 'package:source_gen/source_gen.dart';

/// `source_gen` generator that materialises an `@McpTool`-annotated Dart
/// function into a `ToolDefinition` constant plus a typed handler adapter.
///
/// Registered indirectly via `mcpToolBuilder` + `build.yaml`; end-users
/// typically never instantiate this class themselves.
class McpToolGenerator extends GeneratorForAnnotation<McpTool> {
  /// Creates a stateless generator. Safe to share across builds.
  const McpToolGenerator();

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final function = _asFunction(element, '@McpTool');
    _requireFutureReturn(function, expectedReturn: 'ToolResult');

    final annotatedNameReader = annotation.read('name');
    final toolName = annotatedNameReader.isNull
        ? _snakeCase(function.name)
        : annotatedNameReader.stringValue;
    final description = annotation.read('description').stringValue;
    final allowAdditional = annotation
        .read('allowAdditionalArguments')
        .boolValue;

    final params = _readNamedParameters(function);

    final functionName = function.name;
    final definitionName = '${functionName}Definition';
    final handlerName = '${functionName}Handler';

    final argumentTypesLiteral = params.argumentTypesLiteral;
    final requiredArgsLiteral = params.requiredArgsLiteral;
    final handlerCall = params.callExpression(functionName);

    return '''
const ToolDefinition $definitionName = ToolDefinition(
  name: ${_dartStringLiteral(toolName)},
  description: ${_dartStringLiteral(description)},
  argumentTypes: $argumentTypesLiteral,
  requiredArguments: $requiredArgsLiteral,
  allowAdditionalArguments: $allowAdditional,
);

Future<ToolResult> $handlerName(ToolCall call) {
  return $handlerCall;
}
''';
  }
}

/// Generator for `@McpToolPreview` functions. Emits a
/// `<fn>Previewer(ToolCall)` adapter that unmarshals the typed arguments and
/// calls the annotated function.
class McpToolPreviewGenerator extends GeneratorForAnnotation<McpToolPreview> {
  /// Creates a stateless generator. Safe to share across builds.
  const McpToolPreviewGenerator();

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final function = _asFunction(element, '@McpToolPreview');
    _requireFutureReturn(function, expectedReturn: 'Preview');
    final params = _readNamedParameters(function);

    final functionName = function.name;
    final previewerName = '${functionName}Previewer';
    final call = params.callExpression(functionName);

    return '''
Future<Preview> $previewerName(ToolCall call) {
  return $call;
}
''';
  }
}

/// Generator for `@McpToolUndo` functions. Emits a
/// `<fn>Undoer(ToolCall, ToolResult)` adapter that unmarshals the typed
/// arguments (from the original call) and calls the annotated function.
class McpToolUndoGenerator extends GeneratorForAnnotation<McpToolUndo> {
  /// Creates a stateless generator. Safe to share across builds.
  const McpToolUndoGenerator();

  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final function = _asFunction(element, '@McpToolUndo');
    _requireFutureReturn(function, expectedReturn: 'ToolResult');
    final params = _readNamedParameters(function);

    final functionName = function.name;
    final undoerName = '${functionName}Undoer';
    final call = params.callExpression(functionName);

    return '''
Future<ToolResult> $undoerName(ToolCall call, ToolResult original) {
  return $call;
}
''';
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

FunctionElement _asFunction(Element element, String annotationName) {
  if (element is! FunctionElement) {
    throw InvalidGenerationSourceError(
      '$annotationName can only be applied to top-level functions.',
      element: element,
    );
  }
  if (element.name.isEmpty) {
    throw InvalidGenerationSourceError(
      '$annotationName requires a named function.',
      element: element,
    );
  }
  return element;
}

void _requireFutureReturn(
  FunctionElement function, {
  required String expectedReturn,
}) {
  final type = function.returnType;
  if (type is! InterfaceType ||
      type.element.name != 'Future' ||
      type.typeArguments.length != 1) {
    throw InvalidGenerationSourceError(
      '${function.name} must return Future<$expectedReturn>.',
      element: function,
    );
  }
  final inner = type.typeArguments.single;
  if (inner is! InterfaceType || inner.element.name != expectedReturn) {
    throw InvalidGenerationSourceError(
      '${function.name} must return Future<$expectedReturn>.',
      element: function,
    );
  }
}

class _ParsedParameters {
  _ParsedParameters({
    required this.argumentTypesLiteral,
    required this.requiredArgsLiteral,
    required this.handlerArgs,
  });

  final String argumentTypesLiteral;
  final String requiredArgsLiteral;
  final List<String> handlerArgs;

  String callExpression(String functionName) {
    if (handlerArgs.isEmpty) return '$functionName()';
    return '$functionName(\n    ${handlerArgs.join(',\n    ')},\n  )';
  }
}

_ParsedParameters _readNamedParameters(FunctionElement function) {
  final argumentEntries = <String>[];
  final requiredArgs = <String>[];
  final handlerArgs = <String>[];

  for (final parameter in function.parameters) {
    final paramName = parameter.name;
    if (!parameter.isNamed) {
      throw InvalidGenerationSourceError(
        '${function.name}: parameter `$paramName` must be a named '
        'parameter. Positional parameters are not supported.',
        element: parameter,
      );
    }

    final argTypeName = _toolArgTypeName(parameter.type);
    if (argTypeName == null) {
      throw InvalidGenerationSourceError(
        '${function.name}: parameter `$paramName` has unsupported type '
        '`${parameter.type.getDisplayString()}`. Supported types: String, '
        'int, double, num, bool, List<...>, Map<K, V>.',
        element: parameter,
      );
    }

    argumentEntries.add("'$paramName': ToolArgType.$argTypeName");
    if (parameter.isRequiredNamed) requiredArgs.add("'$paramName'");
    handlerArgs.add('$paramName: ${_argumentCastExpression(parameter)}');
  }

  final argumentTypesLiteral = argumentEntries.isEmpty
      ? '<String, ToolArgType>{}'
      : '{\n    ${argumentEntries.join(',\n    ')},\n  }';
  final requiredArgsLiteral = requiredArgs.isEmpty
      ? '<String>{}'
      : '{${requiredArgs.join(', ')}}';

  return _ParsedParameters(
    argumentTypesLiteral: argumentTypesLiteral,
    requiredArgsLiteral: requiredArgsLiteral,
    handlerArgs: handlerArgs,
  );
}

String? _toolArgTypeName(DartType type) {
  if (type.isDartCoreString) return 'string';
  if (type.isDartCoreInt) return 'integer';
  if (type.isDartCoreDouble || type.isDartCoreNum) return 'number';
  if (type.isDartCoreBool) return 'boolean';
  if (type.isDartCoreList) return 'array';
  if (type.isDartCoreMap) return 'object';
  return null;
}

String _argumentCastExpression(ParameterElement parameter) {
  final type = parameter.type;
  final rawAccess = "call.arguments['${parameter.name}']";
  final declaredNullable = type.nullabilitySuffix == NullabilitySuffix.question;

  final defaultCode = parameter.hasDefaultValue
      ? parameter.defaultValueCode
      : null;
  final useNullableCast = declaredNullable || defaultCode != null;

  final castExpr = _castExpression(type, rawAccess, nullable: useNullableCast);
  return defaultCode == null ? castExpr : '$castExpr ?? $defaultCode';
}

String _castExpression(
  DartType type,
  String rawAccess, {
  required bool nullable,
}) {
  if (type.isDartCoreList && type is InterfaceType) {
    final elementType = type.typeArguments.single.getDisplayString();
    return nullable
        ? '($rawAccess as List?)?.cast<$elementType>()'
        : '($rawAccess as List).cast<$elementType>()';
  }

  if (type.isDartCoreMap && type is InterfaceType) {
    final keyType = type.typeArguments[0].getDisplayString();
    final valueType = type.typeArguments[1].getDisplayString();
    return nullable
        ? '($rawAccess as Map?)?.cast<$keyType, $valueType>()'
        : '($rawAccess as Map).cast<$keyType, $valueType>()';
  }

  final nullSuffix = nullable ? '?' : '';
  return '$rawAccess as ${_bareTypeName(type)}$nullSuffix';
}

String _bareTypeName(DartType type) {
  final display = type.getDisplayString();
  return display.endsWith('?')
      ? display.substring(0, display.length - 1)
      : display;
}

// Emit a single-quoted Dart string literal. The `\$` escape is essential:
// descriptions like `"\$100"` or `"\${foo}"` would otherwise trigger
// interpolation in the generated code.
String _dartStringLiteral(String input) {
  final escaped = input
      .replaceAll(r'\', r'\\')
      .replaceAll(r'$', r'\$')
      .replaceAll("'", r"\'")
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t')
      .replaceAll('\b', r'\b')
      .replaceAll('\f', r'\f');
  return "'$escaped'";
}

String _snakeCase(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
    if (isUpper && i > 0) {
      buffer.write('_');
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}
