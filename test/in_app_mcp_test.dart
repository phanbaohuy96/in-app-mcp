import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('in_app_mcp runtime', () {
    test('returns tool_not_found for unknown tool', () async {
      final mcp = InAppMcp();
      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'missing', arguments: {}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'tool_not_found');
    });

    test('blocks when policy is deny', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.setToolPolicy('x', ToolPolicy.deny);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '2', toolName: 'x', arguments: {'hour': 6}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'policy_denied');
    });

    test('requires confirmation when policy is confirm', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.setToolPolicy('x', ToolPolicy.confirm);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '3', toolName: 'x', arguments: {'hour': 6}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'confirmation_required');
    });

    test('executes when confirmed', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done', data: {'ok': true}),
      );

      await mcp.setToolPolicy('x', ToolPolicy.confirm);
      final result = await mcp.handleToolCall(
        const ToolCall(id: '4', toolName: 'x', arguments: {'hour': 6}),
        confirmed: true,
      );

      expect(result.success, isTrue);
      expect(result.message, 'done');
      expect(result.data['ok'], true);
    });

    test('serializes a JSON schema for a tool definition', () {
      const definition = ToolDefinition(
        name: 'schedule_weekday_alarm',
        description: 'Set a repeating alarm.',
        argumentTypes: {
          'hour': ToolArgType.integer,
          'weekdays': ToolArgType.array,
          'label': ToolArgType.string,
        },
        requiredArguments: {'hour', 'weekdays'},
        allowAdditionalArguments: false,
      );

      final schema = definition.toJsonSchema();

      expect(schema['name'], 'schedule_weekday_alarm');
      expect(schema['description'], 'Set a repeating alarm.');
      final parameters = schema['parameters'] as Map<String, dynamic>;
      expect(parameters['type'], 'object');
      expect(parameters['additionalProperties'], isFalse);
      expect(parameters['required'], ['hour', 'weekdays']);
      final properties = parameters['properties'] as Map<String, dynamic>;
      expect(properties['hour'], {'type': 'integer'});
      expect(properties['weekdays'], {'type': 'array'});
      expect(properties['label'], {'type': 'string'});
    });

    test('ToolArgType names match JSON Schema vocabulary', () {
      // toJsonSchema relies on ToolArgType.name producing these exact strings.
      // A rename of any enum value would silently break LLM tool schemas.
      expect(ToolArgType.string.name, 'string');
      expect(ToolArgType.integer.name, 'integer');
      expect(ToolArgType.number.name, 'number');
      expect(ToolArgType.boolean.name, 'boolean');
      expect(ToolArgType.array.name, 'array');
      expect(ToolArgType.object.name, 'object');
    });

    test('aggregates schemas for all registered tools', () {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'a',
          description: 'a tool',
          argumentTypes: {'x': ToolArgType.integer},
          requiredArguments: {'x'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('ok'),
      );
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'b',
          description: 'b tool',
          argumentTypes: {'y': ToolArgType.string},
        ),
        handler: (call) async => ToolResult.ok('ok'),
      );

      final schema = mcp.toolsSchemaJson();
      final tools = schema['tools'] as List;
      expect(tools, hasLength(2));
      expect((tools[0] as Map)['name'], 'a');
      expect((tools[1] as Map)['name'], 'b');
    });

    test('validates argument schema', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'hour': ToolArgType.integer},
          requiredArguments: {'hour'},
          allowAdditionalArguments: false,
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      final result = await mcp.handleToolCall(
        const ToolCall(id: '5', toolName: 'x', arguments: {'hour': '6'}),
      );

      expect(result.success, isFalse);
      expect(result.code, 'invalid_arguments');
    });
  });

  group('model serialization', () {
    test('ToolResult.toJson includes fields', () {
      final result = ToolResult.ok('ok', data: {'a': 1});
      final json = result.toJson();

      expect(json['success'], true);
      expect(json['message'], 'ok');
      expect(json['data'], {'a': 1});
    });

    test('ToolCall.fromJson parses fields', () {
      final call = ToolCall.fromJson({
        'id': 'abc',
        'toolName': 'test_tool',
        'arguments': {'x': 1},
        'requestId': 'r1',
      });

      expect(call.id, 'abc');
      expect(call.toolName, 'test_tool');
      expect(call.arguments['x'], 1);
      expect(call.requestId, 'r1');
    });
  });
}
