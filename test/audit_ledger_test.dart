import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('InMemoryAuditLedger', () {
    test('record assigns a unique id and preserves fields', () async {
      final ledger = InMemoryAuditLedger();
      final call = const ToolCall(id: '1', toolName: 'x', arguments: {});
      final first = await ledger.record(
        call: call,
        result: ToolResult.ok('done'),
      );
      final second = await ledger.record(
        call: call,
        result: ToolResult.ok('done'),
      );
      expect(first.id, isNot(second.id));
      expect(first.result.success, isTrue);
    });

    test('list returns newest first, honours limit + offset', () async {
      final ledger = InMemoryAuditLedger();
      for (var i = 0; i < 5; i++) {
        await ledger.record(
          call: ToolCall(id: '$i', toolName: 'x', arguments: const {}),
          result: ToolResult.ok('$i'),
        );
      }
      final all = await ledger.list();
      expect(all.map((e) => e.call.id), ['4', '3', '2', '1', '0']);
      final page = await ledger.list(limit: 2, offset: 1);
      expect(page.map((e) => e.call.id), ['3', '2']);
    });

    test('markUndone updates the entry and emits on changes stream', () async {
      final ledger = InMemoryAuditLedger();
      final recorded = await ledger.record(
        call: const ToolCall(id: '1', toolName: 'x', arguments: {}),
        result: ToolResult.ok('done'),
      );
      final emissions = <AuditEntry>[];
      final sub = ledger.changes.listen(emissions.add);
      final updated = await ledger.markUndone(
        recorded.id,
        undoResult: ToolResult.ok('reverted'),
      );
      expect(updated?.undone, isTrue);
      expect(updated?.undoResult?.message, 'reverted');
      expect(emissions.single.undone, isTrue);
      await sub.cancel();
      await ledger.close();
    });

    test('markUndone returns null for unknown id', () async {
      final ledger = InMemoryAuditLedger();
      expect(
        await ledger.markUndone(
          'never-existed',
          undoResult: ToolResult.ok('x'),
        ),
        isNull,
      );
    });
  });

  group('InAppMcp with audit ledger', () {
    test('records successful handler execution', () async {
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
      final entries = await mcp.auditLedger!.list();
      expect(entries, hasLength(1));
      expect(entries.first.result.success, isTrue);
      expect(entries.first.resolved?.decision, PolicyDecision.allow);
    });

    test('records tool_not_found with no resolved policy', () async {
      final mcp = InAppMcp();
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'missing', arguments: {}),
      );
      final entry = (await mcp.auditLedger!.list()).single;
      expect(entry.result.code, 'tool_not_found');
      expect(entry.resolved, isNull);
    });

    test('records policy_denied and confirmation_required', () async {
      final mcp = InAppMcp();
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.setToolPolicy('x', ToolPolicy.deny);
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );

      await mcp.setToolPolicy('x', ToolPolicy.confirm);
      await mcp.handleToolCall(
        const ToolCall(id: '2', toolName: 'x', arguments: {}),
      );

      final entries = await mcp.auditLedger!.list();
      expect(entries.map((e) => e.result.code), [
        'confirmation_required',
        'policy_denied',
      ]);
    });

    test('records the grant source when a grant fires', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );
      await mcp.grantOnce('x');
      await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      final entry = (await mcp.auditLedger!.list()).single;
      expect(entry.resolved?.source, PolicySource.grant);
      expect(entry.resolved?.grant?.toolName, 'x');
    });

    test('disabling audit yields a null ledger and no records', () async {
      final mcp = InAppMcp(enableAudit: false, defaultPolicy: ToolPolicy.auto);
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
      expect(mcp.auditLedger, isNull);
    });
  });
}
