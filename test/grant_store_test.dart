import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

void main() {
  group('EphemeralGrant', () {
    test('once — active until consumed, then exhausted', () {
      final g = EphemeralGrant.once('x');
      expect(g.isActive(), isTrue);
      expect(g.isExhausted, isFalse);

      final consumed = g.decrement();
      expect(consumed.isActive(), isFalse);
      expect(consumed.isExhausted, isTrue);
    });

    test('forDuration — active within window, expired after', () {
      final start = DateTime(2026, 4, 18, 12, 0);
      final g = EphemeralGrant.forDuration(
        'x',
        const Duration(minutes: 5),
        now: start,
      );
      expect(g.isActive(now: start.add(const Duration(minutes: 1))), isTrue);
      expect(g.isActive(now: start.add(const Duration(minutes: 5))), isFalse);
      expect(g.isActive(now: start.add(const Duration(minutes: 6))), isFalse);
    });

    test('untilCleared — never expires, never exhausts', () {
      final g = EphemeralGrant.untilCleared('x');
      expect(g.isActive(), isTrue);
      // Decrement is a no-op when remainingUses is null.
      expect(g.decrement().isActive(), isTrue);
    });
  });

  group('InMemoryGrantStore', () {
    test('put / peek returns the stored grant', () async {
      final store = InMemoryGrantStore();
      await store.put(EphemeralGrant.once('x'));
      final grant = await store.peek('x');
      expect(grant?.toolName, 'x');
      expect(grant?.remainingUses, 1);
    });

    test('consume of a one-use grant revokes on exhaustion', () async {
      final store = InMemoryGrantStore();
      await store.put(EphemeralGrant.once('x'));

      final first = await store.consume('x');
      expect(first, isNotNull);
      expect(first!.remainingUses, 1);

      final second = await store.consume('x');
      expect(second, isNull);
      expect(await store.peek('x'), isNull);
    });

    test('consume of an untilCleared grant is stable', () async {
      final store = InMemoryGrantStore();
      await store.put(EphemeralGrant.untilCleared('x'));
      expect(await store.consume('x'), isNotNull);
      expect(await store.consume('x'), isNotNull);
      expect(await store.peek('x'), isNotNull);
    });

    test('revoke removes the grant', () async {
      final store = InMemoryGrantStore();
      await store.put(EphemeralGrant.once('x'));
      await store.revoke('x');
      expect(await store.peek('x'), isNull);
    });

    test('revokeAll clears every grant', () async {
      final store = InMemoryGrantStore();
      await store.put(EphemeralGrant.once('a'));
      await store.put(EphemeralGrant.untilCleared('b'));
      await store.revokeAll();
      expect(await store.listActive(), isEmpty);
    });

    test('listActive filters expired / exhausted grants', () async {
      final store = InMemoryGrantStore();
      final past = DateTime.now().subtract(const Duration(seconds: 1));
      await store.put(
        EphemeralGrant(
          toolName: 'expired',
          policy: ToolPolicy.auto,
          expiresAt: past,
        ),
      );
      await store.put(EphemeralGrant.once('active'));
      final active = await store.listActive();
      expect(active.map((g) => g.toolName), ['active']);
    });
  });

  group('PolicyEngine with grants', () {
    test('active grant overrides stored policy and is consumed', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.deny);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.grantOnce('x');
      final first = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(first.success, isTrue);

      // Grant consumed — second call should hit the stored deny policy.
      final second = await mcp.handleToolCall(
        const ToolCall(id: '2', toolName: 'x', arguments: {}),
      );
      expect(second.success, isFalse);
      expect(second.code, 'policy_denied');
    });

    test('grantFor keeps multiple calls allowed within the window', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.grantFor('x', const Duration(minutes: 5));
      for (var i = 0; i < 3; i++) {
        final result = await mcp.handleToolCall(
          ToolCall(id: '$i', toolName: 'x', arguments: const {}),
        );
        expect(result.success, isTrue, reason: 'call $i should succeed');
      }
    });

    test('grantUntilCleared stays active until revokeGrant', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );

      await mcp.grantUntilCleared('x');
      final before = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(before.success, isTrue);

      await mcp.revokeGrant('x');
      final after = await mcp.handleToolCall(
        const ToolCall(id: '2', toolName: 'x', arguments: {}),
      );
      expect(after.success, isFalse);
      expect(after.code, 'confirmation_required');
    });

    test('getPolicyDecision peeks without consuming', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.deny);
      mcp.registerTool(
        definition: const ToolDefinition(
          name: 'x',
          description: 'x',
          argumentTypes: {},
        ),
        handler: (call) async => ToolResult.ok('done'),
      );
      await mcp.grantOnce('x');

      // Peek twice — the grant should remain.
      expect(await mcp.getPolicyDecision('x'), PolicyDecision.allow);
      expect(await mcp.getPolicyDecision('x'), PolicyDecision.allow);

      final resolved = await mcp.getResolvedPolicy('x');
      expect(resolved.source, PolicySource.grant);
      expect(resolved.grant?.toolName, 'x');

      // Consuming call still works — peek didn't eat the grant.
      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(result.success, isTrue);
    });

    test('grant APIs throw when grants are disabled', () async {
      final mcp = InAppMcp(enableGrants: false);
      expect(() => mcp.grantOnce('x'), throwsA(isA<StateError>()));
      expect(() => mcp.revokeGrant('x'), throwsA(isA<StateError>()));
      expect(() => mcp.listActiveGrants(), throwsA(isA<StateError>()));
    });

    test('listActiveGrants returns every active grant', () async {
      final mcp = InAppMcp();
      await mcp.grantOnce('a');
      await mcp.grantUntilCleared('b');
      final active = await mcp.listActiveGrants();
      expect(active.map((g) => g.toolName).toSet(), {'a', 'b'});
    });
  });
}
