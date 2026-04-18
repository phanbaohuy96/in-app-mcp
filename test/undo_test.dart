import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('InAppMcp.undoFromLedger', () {
    test('runs the undoer and marks the ledger entry undone', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      var undoCallCount = 0;
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {'message': ToolArgType.string},
          requiredArguments: {'message'},
        ),
        handler: (call) async => ToolResult.ok(
          'scheduled',
          data: {'token': 'abc', 'message': call.arguments['message']},
        ),
        undoer: (call, original) async {
          undoCallCount++;
          return ToolResult.ok(
            'reverted',
            data: {'token': original.data['token']},
          );
        },
      );

      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {'message': 'hello'}),
      );

      final entry = (await mcp.auditLedger!.list()).single;
      expect(entry.undone, isFalse);

      final undo = await mcp.undoFromLedger(entry.id);
      expect(undo.success, isTrue);
      expect(undo.data['token'], 'abc');
      expect(undoCallCount, 1);

      final refreshed = await mcp.auditLedger!.get(entry.id);
      expect(refreshed?.undone, isTrue);
      expect(refreshed?.undoResult?.message, 'reverted');
    });

    test('fails with entry_not_found for unknown ids', () async {
      final mcp = InAppMcp();
      final result = await mcp.undoFromLedger('does-not-exist');
      expect(result.code, 'entry_not_found');
    });

    test(
      'fails with undo_not_supported when no undoer is registered',
      () async {
        final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
        mcp.registerTool(
          definition: const ToolDefinition(
            name: 'x',
            description: 'x',
            argumentTypes: {},
          ),
          handler: (call) async => ToolResult.ok('done'),
        );
        await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'x', arguments: {}),
        );
        final entryId = (await mcp.auditLedger!.list()).single.id;

        final result = await mcp.undoFromLedger(entryId);
        expect(result.code, 'undo_not_supported');
      },
    );

    test('fails with nothing_to_undo when the original failed', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.deny);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
        undoer: (call, original) async => ToolResult.ok('reverted'),
      );
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      final entryId = (await mcp.auditLedger!.list()).single.id;

      final result = await mcp.undoFromLedger(entryId);
      expect(result.code, 'nothing_to_undo');
    });

    test('fails with already_undone on the second undo', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
        undoer: (call, original) async => ToolResult.ok('reverted'),
      );
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      final entryId = (await mcp.auditLedger!.list()).single.id;

      final first = await mcp.undoFromLedger(entryId);
      expect(first.success, isTrue);
      final second = await mcp.undoFromLedger(entryId);
      expect(second.code, 'already_undone');
    });

    test('fails with audit_disabled when ledger is off', () async {
      final mcp = InAppMcp(enableAudit: false);
      final result = await mcp.undoFromLedger('any');
      expect(result.code, 'audit_disabled');
    });

    test('failing undoer leaves the entry in its original state', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
        undoer: (call, original) async =>
            ToolResult.fail('handler_error', 'nope'),
      );
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      final entryId = (await mcp.auditLedger!.list()).single.id;

      final result = await mcp.undoFromLedger(entryId);
      expect(result.success, isFalse);
      expect(result.code, 'handler_error');

      final refreshed = await mcp.auditLedger!.get(entryId);
      expect(refreshed?.undone, isFalse);
    });
  });
}
