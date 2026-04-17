import 'tool_call.dart';
import 'tool_result.dart';

enum ToolArgType {
  string,
  integer,
  number,
  boolean,
  array,
  object,
}

typedef ToolHandler = Future<ToolResult> Function(ToolCall call);

class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.argumentTypes,
    this.requiredArguments = const {},
    this.allowAdditionalArguments = true,
  });

  final String name;
  final String description;
  final Map<String, ToolArgType> argumentTypes;
  final Set<String> requiredArguments;
  final bool allowAdditionalArguments;

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
}
