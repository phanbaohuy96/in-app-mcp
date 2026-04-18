// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end exercise of the Consent Lifecycle:
/// preview → ephemeral grant → execute → audit → undo.
///
/// Runs headless against a real [InAppMcp] runtime so we cover the full
/// composition (policy engine + grant store + audit ledger + registry)
/// without needing a Flutter simulator or a network call.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InAppMcp mcp;
  final scheduled = <String>[];
  final cancelled = <String>[];

  setUp(() {
    scheduled.clear();
    cancelled.clear();
    mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
    mcp.registerTool(
      definition: const ToolDefinition(
        name: 'schedule_alarm',
        description: 'Schedule a test alarm.',
        argumentTypes: {'label': ToolArgType.string},
        requiredArguments: {'label'},
      ),
      handler: (call) async {
        final token = 'alarm-${scheduled.length}';
        scheduled.add(token);
        return ToolResult.ok(
          'Scheduled.',
          data: {'token': token, 'label': call.arguments['label']},
        );
      },
      previewer: (call) async => Preview(
        summary: 'Would schedule "${call.arguments['label']}".',
        data: {'label': call.arguments['label']},
      ),
      undoer: (call, original) async {
        cancelled.add(original.data['token'] as String);
        return ToolResult.ok('Cancelled.');
      },
    );
  });

  tearDown(() async => mcp.dispose());

  testWidgets('preview runs without side effect', (_) async {
    final preview = await mcp.previewToolCall(
      const ToolCall(
        id: 'c1',
        toolName: 'schedule_alarm',
        arguments: {'label': 'wake'},
      ),
    );
    expect(preview, isNotNull);
    expect(preview!.summary, contains('wake'));
    expect(scheduled, isEmpty);
  });

  testWidgets('unconfirmed call short-circuits as confirmation_required', (
    _,
  ) async {
    final result = await mcp.handleToolCall(
      const ToolCall(
        id: 'c2',
        toolName: 'schedule_alarm',
        arguments: {'label': 'a'},
      ),
    );
    expect(result.code, ToolErrorCode.confirmationRequired);
    expect(scheduled, isEmpty);

    final entry = (await mcp.auditLedger!.list()).single;
    expect(entry.result.code, ToolErrorCode.confirmationRequired);
    expect(entry.resolved?.source, PolicySource.stored);
  });

  testWidgets('grantFor upgrades policy, execution succeeds, ledger records '
      'grant source, undo reverses effect', (_) async {
    final entries = <AuditEntry>[];
    final sub = mcp.auditLedger!.changes.listen(entries.add);

    await mcp.grantFor('schedule_alarm', const Duration(minutes: 5));
    final result = await mcp.handleToolCall(
      const ToolCall(
        id: 'c3',
        toolName: 'schedule_alarm',
        arguments: {'label': 'wake'},
      ),
    );
    expect(result.success, isTrue);
    expect(scheduled, ['alarm-0']);

    // Ledger stream emitted the entry.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.result.success, isTrue);
    expect(entry.resolved?.source, PolicySource.grant);

    // Undo consumes the same entry; tool's undoer fires.
    final undo = await mcp.undoFromLedger(entry.id);
    expect(undo.success, isTrue);
    expect(cancelled, ['alarm-0']);

    final refreshed = await mcp.auditLedger!.get(entry.id);
    expect(refreshed?.undone, isTrue);

    // Second undo short-circuits as already_undone.
    final again = await mcp.undoFromLedger(entry.id);
    expect(again.code, ToolErrorCode.alreadyUndone);

    await sub.cancel();
  });

  testWidgets(
    'grantOnce consumes after first use; next call falls back to stored policy',
    (_) async {
      await mcp.grantOnce('schedule_alarm');
      final first = await mcp.handleToolCall(
        const ToolCall(
          id: 'c4',
          toolName: 'schedule_alarm',
          arguments: {'label': 'one'},
        ),
      );
      expect(first.success, isTrue);

      final second = await mcp.handleToolCall(
        const ToolCall(
          id: 'c5',
          toolName: 'schedule_alarm',
          arguments: {'label': 'two'},
        ),
      );
      expect(second.code, ToolErrorCode.confirmationRequired);
      expect(scheduled, ['alarm-0']);
    },
  );

  testWidgets('revokeAllGrants clears session grant', (_) async {
    await mcp.grantUntilCleared('schedule_alarm');
    expect(await mcp.listActiveGrants(), hasLength(1));

    await mcp.revokeAllGrants();
    expect(await mcp.listActiveGrants(), isEmpty);

    final result = await mcp.handleToolCall(
      const ToolCall(
        id: 'c6',
        toolName: 'schedule_alarm',
        arguments: {'label': 'x'},
      ),
    );
    expect(result.code, ToolErrorCode.confirmationRequired);
  });
}
