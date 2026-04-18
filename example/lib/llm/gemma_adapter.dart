import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_litert_lm/flutter_litert_lm.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import '../agent_tools/tool_catalog.dart';
import 'llm_adapter.dart';
import 'llm_adapter_mode.dart';
import 'tool_call_parser.dart';

enum _SchemaType { integer, number, boolean, array, object, string }

final _unquotedKeyPattern = RegExp(r'([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)');

/// Quote bareword object keys inside a JSON-ish string.
///
/// `{"foo":1,bar:2}` → `{"foo":1,"bar":2}`. Keys that are already quoted are
/// left alone — the regex only matches identifiers that immediately follow
/// `{` or `,` (i.e. object-entry starts), never positions that follow `:`.
String quoteUnquotedObjectKeys(String input) {
  return input.replaceAllMapped(
    _unquotedKeyPattern,
    (match) => '${match[1]}"${match[2]}"${match[3]}',
  );
}

class GemmaAdapter extends LlmAdapter {
  GemmaAdapter({
    required this.modelPath,
    required this.toolSchema,
    this.deterministicMode = false,
  }) : _tools = _parseTools(toolSchema);

  final String modelPath;
  final String toolSchema;
  final bool deterministicMode;
  final List<LiteLmTool> _tools;

  static const _defaultToolCallMessage = 'I prepared a tool call.';

  late final String _modelInputPrefix = _buildModelInputPrefix(_tools);

  LiteLmEngine? _engine;
  LiteLmConversation? _conversation;
  String? _loadedPath;
  Future<void>? _initializing;

  @override
  LlmAdapterMode get mode => LlmAdapterMode.gemma4;

  @override
  String get id => adapterIdForPath(modelPath);

  static String adapterIdForPath(String modelPath) {
    final path = modelPath.trim();
    if (path.isEmpty) {
      return 'gemma4';
    }
    final parts = path.split('/');
    return 'gemma4:${parts.isEmpty ? path : parts.last}';
  }

  @override
  Future<LlmTurn> buildTurn(String userPrompt) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Sending user prompt to Gemma: $userPrompt');
    }
    if (deterministicMode) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Deterministic mode enabled; returning fixed tool call.');
      }
      return LlmTurn(
        message: 'I can open directions to Tokyo.',
        toolCall: ToolCall(
          id: 'e2e-deterministic-1',
          toolName: openMapDirectionsDefinition.name,
          arguments: const {'destination': 'Tokyo', 'travelMode': 'driving'},
        ),
      );
    }

    final path = modelPath.trim();
    if (path.isEmpty) {
      throw StateError('Gemma model path is not set.');
    }
    if (kDebugMode) {
      // ignore: avoid_print
      print('Using Gemma model path: $path');
    }
    try {
      await _ensureConversation(path);
      final conversation = _conversation;
      if (conversation == null) {
        throw StateError('Gemma conversation is not initialized.');
      }
      final modelInput = _buildModelInput(userPrompt);
      if (kDebugMode) {
        // ignore: avoid_print
        print('Model input:\n$modelInput');
      }
      final response = await conversation.sendMessage(modelInput);
      final responseText = response.text.trim();
      final toolCalls = response.toolCalls;
      if (kDebugMode) {
        // ignore: avoid_print
        print('Received response from Gemma: ${response.text}');
      }
      if (toolCalls.isNotEmpty) {
        final call = toolCalls.first;
        return _toTurn(
          responseText,
          call.name,
          _normalizeArguments(call.name, call.arguments, userPrompt),
        );
      }

      if (responseText.isNotEmpty) {
        final parsedCall = _parseToolCallFromText(responseText);
        if (parsedCall != null) {
          return _toTurn(
            _assistantMessageForParsedToolCall(responseText),
            parsedCall.toolName,
            _normalizeArguments(
              parsedCall.toolName,
              parsedCall.arguments,
              userPrompt,
            ),
            id: parsedCall.id,
          );
        }
        return LlmTurn(message: responseText);
      }

      return const LlmTurn(
        message:
            'I did not generate a tool call for that. Please clarify your request.',
      );
    } catch (e) {
      throw StateError('Gemma inference failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _disposeRuntime();
  }

  Future<void> _ensureConversation(String path) async {
    if (_conversation != null && _loadedPath == path) {
      return;
    }

    if (_initializing != null) {
      await _initializing;
      if (_conversation != null && _loadedPath == path) {
        return;
      }
    }

    final init = () async {
      await _disposeRuntime();
      final engine = await LiteLmEngine.create(
        LiteLmEngineConfig(modelPath: path, backend: LiteLmBackend.cpu),
      );
      final conversation = await engine.createConversation(
        LiteLmConversationConfig(
          systemInstruction:
              'You are an on-device assistant inside a mobile app. Answer naturally, and follow tool-use instructions provided in each user message.',
          samplerConfig: const LiteLmSamplerConfig(
            topK: 40,
            topP: 0.95,
            temperature: 0.2,
          ),
          tools: _tools,
          automaticToolCalling: false,
        ),
      );

      _engine = engine;
      _conversation = conversation;
      _loadedPath = path;
    }();

    _initializing = init;
    try {
      await init;
    } finally {
      if (identical(_initializing, init)) {
        _initializing = null;
      }
    }
  }

  Future<void> _disposeRuntime() async {
    final conversation = _conversation;
    _conversation = null;
    _loadedPath = null;
    if (conversation != null) {
      await conversation.dispose();
    }

    final engine = _engine;
    _engine = null;
    if (engine != null) {
      await engine.dispose();
    }
  }

  static List<LiteLmTool> _parseTools(String schema) {
    try {
      final decoded = jsonDecode(schema);
      if (decoded is! Map) {
        return const [];
      }
      final tools = decoded['tools'];
      if (tools is! List) {
        return const [];
      }

      final parsed = <LiteLmTool>[];
      for (final entry in tools) {
        if (entry is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(entry);
        final name = (map['name'] ?? '').toString().trim();
        if (name.isEmpty) {
          continue;
        }
        final description = (map['description'] ?? '').toString();
        final required = ((map['requiredArguments'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList(growable: false);

        final rawTypes = Map<String, dynamic>.from(
          (map['argumentTypes'] as Map?) ?? const <String, dynamic>{},
        );
        final properties = <String, dynamic>{
          for (final item in rawTypes.entries)
            item.key: {'type': _schemaType(item.value.toString()).name},
        };

        parsed.add(
          LiteLmTool(
            name: name,
            description: description,
            parameters: {
              'type': 'object',
              'properties': properties,
              'required': required,
              'additionalProperties': false,
            },
          ),
        );
      }
      return parsed;
    } catch (_) {
      return const [];
    }
  }

  String _buildModelInput(String userPrompt) {
    return '''
$_modelInputPrefix

User request:
$userPrompt
''';
  }

  String _buildModelInputPrefix(List<LiteLmTool> tools) {
    final availableTools = tools.map(_toolLine).join('\n');
    return '''
You are inside a mobile app that can execute app tools on the user's behalf.
Never say you cannot access tools.

Available tools:
$availableTools

Output rules:
- If one tool applies, respond with one short assistant sentence, then a JSON object with this exact shape:
  {"toolName":"<tool>","arguments":{...}}
- Use only tool names from the available tools list.
- For schedule_weekday_alarm, weekdays must be integers 1..7 (Monday=1, ..., Sunday=7).
- If the user says weekdays/workdays, use [1,2,3,4,5] unless they explicitly ask for weekend or every day.
- If no tool applies, respond with normal text only and do not include JSON.
''';
  }

  String _toolLine(LiteLmTool tool) {
    final properties = Map<String, dynamic>.from(
      (tool.parameters['properties'] as Map?) ?? const <String, dynamic>{},
    );
    final required = ((tool.parameters['required'] as List?) ?? const [])
        .map((item) => item.toString())
        .toSet();

    final args = properties.entries
        .map((entry) {
          final type = ((entry.value as Map?)?['type'] ?? 'string').toString();
          final isRequired = required.contains(entry.key)
              ? 'required'
              : 'optional';
          return '${entry.key}:$type($isRequired)';
        })
        .join(', ');

    return '- ${tool.name}: ${tool.description} Args: {$args}';
  }

  LlmTurn _toTurn(
    String assistantText,
    String toolName,
    Map<String, dynamic> arguments, {
    String? id,
  }) {
    return LlmTurn(
      message: assistantText.isEmpty ? _defaultToolCallMessage : assistantText,
      toolCall: ToolCall(
        id: id ?? newToolCallId(),
        toolName: toolName,
        arguments: Map<String, dynamic>.from(arguments),
      ),
    );
  }

  ToolCall? _parseToolCallFromText(String text) {
    final firstBrace = text.indexOf('{');
    final lastBrace = text.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) {
      return null;
    }

    final candidate = text.substring(firstBrace, lastBrace + 1);
    if (!candidate.contains('"toolName"')) {
      return null;
    }

    // Gemma 4 E2B sometimes emits JSON with unquoted object keys, e.g.
    // {"toolName":"x","arguments":{hour:6,minute:0}}. strict jsonDecode
    // rejects this; preprocess to quote unquoted keys before parsing.
    final normalized = quoteUnquotedObjectKeys(candidate);

    try {
      return const ToolCallParser().parse(normalized);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _normalizeArguments(
    String toolName,
    Map<String, dynamic> arguments,
    String userPrompt,
  ) {
    final normalized = Map<String, dynamic>.from(arguments);
    if (toolName == scheduleWeekdayAlarmDefinition.name) {
      final weekdays = _normalizeWeekdays(normalized['weekdays']);
      normalized['weekdays'] = _preferWeekdaysFromPrompt(userPrompt)
          ? const [1, 2, 3, 4, 5]
          : weekdays;
    }
    return normalized;
  }

  List<int> _normalizeWeekdays(Object? rawWeekdays) {
    if (rawWeekdays is! List) {
      return const [1, 2, 3, 4, 5];
    }

    final mapped = <int>[];
    for (final item in rawWeekdays) {
      final value = _weekdayToInt(item);
      if (value != null &&
          value >= 1 &&
          value <= 7 &&
          !mapped.contains(value)) {
        mapped.add(value);
      }
    }

    if (mapped.isEmpty) {
      return const [1, 2, 3, 4, 5];
    }
    return mapped;
  }

  bool _preferWeekdaysFromPrompt(String userPrompt) {
    final text = userPrompt.toLowerCase();
    final asksWeekdays =
        text.contains('weekday') ||
        text.contains('weekdays') ||
        text.contains('workday');
    if (!asksWeekdays) {
      return false;
    }

    final asksEveryDay =
        text.contains('every day') ||
        text.contains('everyday') ||
        text.contains('daily');
    final asksWeekend =
        text.contains('weekend') ||
        text.contains('saturday') ||
        text.contains('sunday');
    return !asksEveryDay && !asksWeekend;
  }

  int? _weekdayToInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      const byName = <String, int>{
        '1': 1,
        'monday': 1,
        'mon': 1,
        '2': 2,
        'tuesday': 2,
        'tue': 2,
        'tues': 2,
        '3': 3,
        'wednesday': 3,
        'wed': 3,
        '4': 4,
        'thursday': 4,
        'thu': 4,
        'thur': 4,
        'thurs': 4,
        '5': 5,
        'friday': 5,
        'fri': 5,
        '6': 6,
        'saturday': 6,
        'sat': 6,
        '7': 7,
        'sunday': 7,
        'sun': 7,
      };
      return byName[normalized];
    }
    return null;
  }

  String _assistantMessageForParsedToolCall(String text) {
    final firstBrace = text.indexOf('{');
    if (firstBrace <= 0) {
      return _defaultToolCallMessage;
    }
    final message = text.substring(0, firstBrace).trim();
    return message.isEmpty ? _defaultToolCallMessage : message;
  }

  static _SchemaType _schemaType(String typeName) {
    return switch (typeName) {
      'integer' => _SchemaType.integer,
      'double' || 'number' => _SchemaType.number,
      'boolean' => _SchemaType.boolean,
      'array' => _SchemaType.array,
      'object' => _SchemaType.object,
      _ => _SchemaType.string,
    };
  }
}
