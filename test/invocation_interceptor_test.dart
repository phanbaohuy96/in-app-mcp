import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

ToolDefinition _def(String name) =>
    ToolDefinition(name: name, description: name, argumentTypes: const {});

void main() {
  group('InvocationInterceptor', () {
    test('empty interceptor list is a no-op', () async {
      final mcp = InAppMcp(defaultPolicy: ToolPolicy.auto);
      mcp.registerTool(
        definition: _def('x'),
        handler: (_) async => ToolResult.ok('done'),
      );
      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(result.success, isTrue);
      expect(result.message, 'done');
    });

    test(
      'onResolvePolicy override flips allow into deny and records the override',
      () async {
        final mcp = InAppMcp(
          defaultPolicy: ToolPolicy.auto,
          interceptors: [_ForcePolicy(PolicyDecision.deny)],
        );
        mcp.registerTool(
          definition: _def('x'),
          handler: (_) async => ToolResult.ok('done'),
        );

        final result = await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'x', arguments: {}),
        );
        expect(result.success, isFalse);
        expect(result.code, ToolErrorCode.policyDenied);

        final entry = (await mcp.auditLedger!.list()).single;
        expect(entry.resolved?.decision, PolicyDecision.deny);
      },
    );

    test(
      'onResolvePolicy override flips deny into allow and the handler runs',
      () async {
        final mcp = InAppMcp(
          defaultPolicy: ToolPolicy.deny,
          interceptors: [_ForcePolicy(PolicyDecision.allow)],
        );
        var handlerCalled = false;
        mcp.registerTool(
          definition: _def('x'),
          handler: (_) async {
            handlerCalled = true;
            return ToolResult.ok('done');
          },
        );

        final result = await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'x', arguments: {}),
        );
        expect(result.success, isTrue);
        expect(handlerCalled, isTrue);
      },
    );

    test('beforeExecute veto short-circuits the handler', () async {
      var handlerCalled = false;
      final mcp = InAppMcp(
        defaultPolicy: ToolPolicy.auto,
        interceptors: [_RateLimitVeto()],
      );
      mcp.registerTool(
        definition: _def('x'),
        handler: (_) async {
          handlerCalled = true;
          return ToolResult.ok('done');
        },
      );

      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(result.success, isFalse);
      expect(result.code, 'rate_limited');
      expect(handlerCalled, isFalse);
    });

    test(
      'beforeExecute first-wins short-circuits later interceptors',
      () async {
        final second = _RecordingInterceptor();
        final mcp = InAppMcp(
          defaultPolicy: ToolPolicy.auto,
          interceptors: [_RateLimitVeto(), second],
        );
        mcp.registerTool(
          definition: _def('x'),
          handler: (_) async => ToolResult.ok('done'),
        );

        await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'x', arguments: {}),
        );
        expect(
          second.beforeExecuteCalls,
          isEmpty,
          reason: 'second interceptor should not see a veto short-circuit',
        );
      },
    );

    test('afterExecute rewrites propagate through the chain', () async {
      final mcp = InAppMcp(
        defaultPolicy: ToolPolicy.auto,
        interceptors: [_TagResult('a'), _TagResult('b')],
      );
      mcp.registerTool(
        definition: _def('x'),
        handler: (_) async => ToolResult.ok('base'),
      );

      final result = await mcp.handleToolCall(
        const ToolCall(id: '1', toolName: 'x', arguments: {}),
      );
      expect(result.message, 'base+a+b');
    });

    test(
      'onAudit is fire-and-forget — exceptions never break the call',
      () async {
        final mcp = InAppMcp(
          defaultPolicy: ToolPolicy.auto,
          interceptors: [_AuditBoom()],
        );
        mcp.registerTool(
          definition: _def('x'),
          handler: (_) async => ToolResult.ok('done'),
        );

        final result = await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'x', arguments: {}),
        );
        expect(result.success, isTrue);
      },
    );

    test(
      'exceptions from modifying hooks propagate (onResolvePolicy)',
      () async {
        final mcp = InAppMcp(
          defaultPolicy: ToolPolicy.auto,
          interceptors: [_BadResolvePolicy()],
        );
        mcp.registerTool(
          definition: _def('x'),
          handler: (_) async => ToolResult.ok('done'),
        );

        expect(
          () => mcp.handleToolCall(
            const ToolCall(id: '1', toolName: 'x', arguments: {}),
          ),
          throwsStateError,
        );
      },
    );

    test(
      'tool_not_found path still fires onAudit but skips other hooks',
      () async {
        final observer = _RecordingInterceptor();
        final mcp = InAppMcp(interceptors: [observer]);

        await mcp.handleToolCall(
          const ToolCall(id: '1', toolName: 'missing', arguments: {}),
        );

        expect(observer.onResolvePolicyCalls, isEmpty);
        expect(observer.beforeExecuteCalls, isEmpty);
        expect(observer.afterExecuteCalls, isEmpty);
        expect(observer.auditCalls, hasLength(1));
        expect(
          observer.auditCalls.single.result.code,
          ToolErrorCode.toolNotFound,
        );
      },
    );
  });
}

class _ForcePolicy extends InvocationInterceptor {
  _ForcePolicy(this.decision);
  final PolicyDecision decision;

  @override
  Future<ResolvedPolicy?> onResolvePolicy(
    String toolName,
    ResolvedPolicy upstream,
  ) async {
    return ResolvedPolicy(decision: decision, source: PolicySource.stored);
  }
}

class _RateLimitVeto extends InvocationInterceptor {
  @override
  Future<ToolResult?> beforeExecute(
    ToolCall call,
    ResolvedPolicy resolved,
  ) async {
    return ToolResult.fail('rate_limited', 'Too many calls.');
  }
}

class _TagResult extends InvocationInterceptor {
  _TagResult(this.tag);
  final String tag;

  @override
  Future<ToolResult?> afterExecute(ToolCall call, ToolResult result) async {
    return ToolResult.ok('${result.message}+$tag', data: result.data);
  }
}

class _AuditBoom extends InvocationInterceptor {
  @override
  Future<void> onAudit(AuditEntry entry) async {
    throw StateError('telemetry broken');
  }
}

class _BadResolvePolicy extends InvocationInterceptor {
  @override
  Future<ResolvedPolicy?> onResolvePolicy(
    String toolName,
    ResolvedPolicy upstream,
  ) async {
    throw StateError('policy lookup failed');
  }
}

class _RecordingInterceptor extends InvocationInterceptor {
  final onResolvePolicyCalls = <String>[];
  final beforeExecuteCalls = <ToolCall>[];
  final afterExecuteCalls = <ToolCall>[];
  final auditCalls = <AuditEntry>[];

  @override
  Future<ResolvedPolicy?> onResolvePolicy(
    String toolName,
    ResolvedPolicy upstream,
  ) async {
    onResolvePolicyCalls.add(toolName);
    return null;
  }

  @override
  Future<ToolResult?> beforeExecute(
    ToolCall call,
    ResolvedPolicy resolved,
  ) async {
    beforeExecuteCalls.add(call);
    return null;
  }

  @override
  Future<ToolResult?> afterExecute(ToolCall call, ToolResult result) async {
    afterExecuteCalls.add(call);
    return null;
  }

  @override
  Future<void> onAudit(AuditEntry entry) async {
    auditCalls.add(entry);
  }
}
