import 'tool_call.dart';
import 'tool_result.dart';

/// Supported argument types for a [ToolDefinition].
///
/// Values map 1:1 to JSON Schema type names via their `.name` getter, which
/// is relied on by [ToolDefinition.toJsonSchema] and by LLM adapter
/// serialisation.
enum ToolArgType {
  /// `String` value.
  string,

  /// Whole-number `int` value.
  integer,

  /// Any `num` (int or double).
  number,

  /// `bool` value.
  boolean,

  /// `List<dynamic>` value.
  array,

  /// `Map<String, dynamic>` value.
  object,
}

/// Signature of a tool handler registered with [ToolDefinition].
///
/// Handlers receive a validated [ToolCall] and return a [ToolResult].
typedef ToolHandler = Future<ToolResult> Function(ToolCall call);

/// Declarative contract describing a single registered tool.
///
/// A [ToolDefinition] is the runtime's source of truth for a tool's name,
/// human-readable description, argument schema, and validation rules. The
/// runtime uses it to validate [ToolCall] arguments before a handler fires
/// and to export a JSON schema for LLM adapters.
class ToolDefinition {
  /// Creates a tool definition.
  ///
  /// [name] must match the `toolName` of any incoming [ToolCall].
  /// [argumentTypes] declares expected parameter types; every entry in
  /// [requiredArguments] must also appear in [argumentTypes].
  /// When [allowAdditionalArguments] is `false`, unknown keys in a call's
  /// arguments are rejected during validation.
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.argumentTypes,
    this.requiredArguments = const {},
    this.allowAdditionalArguments = true,
  });

  /// Unique tool name; referenced by [ToolCall.toolName] at invocation time.
  final String name;

  /// Short human-readable description shown in UI and surfaced to LLMs
  /// alongside the JSON schema.
  final String description;

  /// Map of argument name → expected [ToolArgType].
  final Map<String, ToolArgType> argumentTypes;

  /// Names of arguments that must be present; absence fails validation with
  /// `invalid_arguments`.
  final Set<String> requiredArguments;

  /// Whether arguments beyond those declared in [argumentTypes] are allowed.
  /// Defaults to `true` for forward compatibility.
  final bool allowAdditionalArguments;

  /// Validates [arguments] against the declared schema.
  ///
  /// Returns an empty list on success, or a list of human-readable error
  /// strings (missing requireds, unknown keys, type mismatches).
  List<String> validateArguments(Map<String, dynamic> arguments) {
    final errors = <String>[];

    for (final requiredKey in requiredArguments) {
      if (!arguments.containsKey(requiredKey)) {
        errors.add('Missing required argument: $requiredKey');
      }
    }

    for (final entry in arguments.entries) {
      final expectedType = argumentTypes[entry.key];
      if (expectedType == null) {
        if (!allowAdditionalArguments) {
          errors.add('Unknown argument: ${entry.key}');
        }
        continue;
      }
      if (!_matchesType(entry.value, expectedType)) {
        errors.add(
          'Invalid type for ${entry.key}: expected ${expectedType.name}',
        );
      }
    }

    return errors;
  }

  bool _matchesType(Object? value, ToolArgType type) {
    return switch (type) {
      ToolArgType.string => value is String,
      ToolArgType.integer => value is int,
      ToolArgType.number => value is num,
      ToolArgType.boolean => value is bool,
      ToolArgType.array => value is List,
      ToolArgType.object => value is Map,
    };
  }

  /// Returns an OpenAI-function-style JSON schema describing this tool.
  ///
  /// Shape: `{"name", "description", "parameters": {"type": "object",
  /// "properties", "required", "additionalProperties"}}`. Useful for
  /// embedding in an LLM prompt or function-calling payload.
  Map<String, dynamic> toJsonSchema() {
    final properties = <String, dynamic>{
      for (final entry in argumentTypes.entries)
        entry.key: {'type': entry.value.name},
    };
    final required = requiredArguments.toList()..sort();
    return {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': properties,
        'required': required,
        'additionalProperties': allowAdditionalArguments,
      },
    };
  }
}
