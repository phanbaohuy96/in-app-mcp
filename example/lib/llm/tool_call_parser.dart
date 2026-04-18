import 'dart:convert';

import 'package:in_app_mcp/in_app_mcp.dart';

String newToolCallId() => DateTime.now().millisecondsSinceEpoch.toString();

class ToolCallParser {
  const ToolCallParser();

  ToolCall parse(Object? payload, {String? fallbackId}) {
    final call = _parseInternal(payload, fallbackId: fallbackId);
    if (call.toolName.isEmpty) {
      throw const FormatException('Missing toolName in tool call payload.');
    }
    return call;
  }

  ToolCall _parseInternal(Object? payload, {String? fallbackId}) {
    if (payload is ToolCall) {
      return payload;
    }

    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);

      if (map['toolCallJson'] is String) {
        return _parseInternal(map['toolCallJson'], fallbackId: fallbackId);
      }
      if (map['toolCall'] != null) {
        return _parseInternal(map['toolCall'], fallbackId: fallbackId);
      }
      if (map['rawText'] is String) {
        final extracted = _extractJsonObject(map['rawText'] as String);
        if (extracted != null) {
          return _parseInternal(extracted, fallbackId: fallbackId);
        }
      }

      final functionCall = map['functionCall'];
      if (functionCall is Map) {
        final fnMap = Map<String, dynamic>.from(functionCall);
        return _buildToolCall(
          toolName: (fnMap['name'] ?? '').toString(),
          rawArgs: fnMap['arguments'] ?? fnMap['args'] ?? const {},
          id: (map['id'] ?? fallbackId ?? newToolCallId()).toString(),
        );
      }

      final function = map['function'];
      if (function is Map) {
        final fnMap = Map<String, dynamic>.from(function);
        return _buildToolCall(
          toolName: (fnMap['name'] ?? '').toString(),
          rawArgs: fnMap['arguments'] ?? fnMap['args'] ?? const {},
          id: (map['id'] ?? fallbackId ?? newToolCallId()).toString(),
        );
      }

      final toolName = (map['toolName'] ?? map['name'] ?? map['tool'] ?? '')
          .toString();
      final rawArgs = map['arguments'] ?? map['args'] ?? const {};
      final id = (map['id'] ?? fallbackId ?? newToolCallId()).toString();
      return _buildToolCall(toolName: toolName, rawArgs: rawArgs, id: id);
    }

    if (payload is String) {
      final decoded = _extractJsonObject(payload);
      if (decoded == null) {
        throw const FormatException('Payload does not contain a JSON object.');
      }
      return _parseInternal(decoded, fallbackId: fallbackId);
    }

    throw const FormatException('Unsupported tool call payload type.');
  }

  ToolCall _buildToolCall({
    required String toolName,
    required Object? rawArgs,
    required String id,
  }) {
    final arguments = _toArgumentsMap(rawArgs);
    return ToolCall(id: id, toolName: toolName, arguments: arguments);
  }

  Map<String, dynamic> _toArgumentsMap(Object? rawArgs) {
    if (rawArgs is Map) {
      return Map<String, dynamic>.from(rawArgs);
    }
    if (rawArgs is String) {
      final decoded = jsonDecode(rawArgs);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    throw const FormatException('Tool arguments must be a JSON object.');
  }

  Map<String, dynamic>? _extractJsonObject(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    final firstBrace = input.indexOf('{');
    final lastBrace = input.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) {
      return null;
    }

    final candidate = input.substring(firstBrace, lastBrace + 1);
    final decoded = jsonDecode(candidate);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return null;
  }
}
