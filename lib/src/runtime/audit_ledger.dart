import 'dart:async';

import '../model/tool_call.dart';
import '../model/tool_result.dart';
import 'policy_engine.dart';

/// One row in the audit ledger — a complete record of a single tool-call
/// lifecycle, from proposal to outcome (and optional undo).
///
/// Every call that passes through `InAppMcp.handleToolCall` produces one
/// entry: successful executions, policy denials, confirmation short-circuits,
/// and missing-tool failures are all captured.
class AuditEntry {
  /// Creates an entry. Usually constructed by [AuditLedger] implementations,
  /// not by callers.
  const AuditEntry({
    required this.id,
    required this.timestamp,
    required this.call,
    required this.result,
    this.resolved,
    this.executionDuration = Duration.zero,
    this.undone = false,
    this.undoneAt,
    this.undoResult,
  });

  /// Unique, stable identifier for this entry (scoped to the ledger).
  final String id;

  /// When the invocation started.
  final DateTime timestamp;

  /// The proposed [ToolCall] at invocation time.
  final ToolCall call;

  /// Final [ToolResult] returned to the caller — always present, including
  /// for pre-execution failures (`tool_not_found`, `policy_denied`,
  /// `confirmation_required`).
  final ToolResult result;

  /// Policy resolution that produced this entry's decision. `null` when the
  /// call short-circuited before policy was consulted (e.g. `tool_not_found`).
  final ResolvedPolicy? resolved;

  /// Wall-clock duration of the full invocation. Defaults to [Duration.zero]
  /// when a ledger implementation chooses not to measure it.
  final Duration executionDuration;

  /// `true` after `InAppMcp.undoFromLedger` has been invoked successfully.
  final bool undone;

  /// When the entry was undone. `null` unless [undone] is `true`.
  final DateTime? undoneAt;

  /// Result of the undo invocation, if any.
  final ToolResult? undoResult;

  /// Returns a copy with undo metadata populated.
  AuditEntry markedUndone({required DateTime at, required ToolResult result}) {
    return AuditEntry(
      id: id,
      timestamp: timestamp,
      call: call,
      result: this.result,
      resolved: resolved,
      executionDuration: executionDuration,
      undone: true,
      undoneAt: at,
      undoResult: result,
    );
  }
}

/// Append-only record of tool invocations.
///
/// Implementations pick a storage medium (in-memory, SharedPreferences, a
/// database, a remote service); the contract is that every call
/// `InAppMcp.handleToolCall` processes produces exactly one [AuditEntry]
/// and that callers can observe new entries via [changes].
abstract class AuditLedger {
  /// Base constructor for subclasses.
  const AuditLedger();

  /// Records a new entry and returns it. Implementations assign the [AuditEntry.id].
  Future<AuditEntry> record({
    required ToolCall call,
    required ToolResult result,
    ResolvedPolicy? resolved,
    DateTime? timestamp,
    Duration executionDuration = Duration.zero,
  });

  /// Marks [id] as undone with [undoResult]. Returns the updated entry, or
  /// `null` if no entry with that id exists.
  Future<AuditEntry?> markUndone(
    String id, {
    required ToolResult undoResult,
    DateTime? at,
  });

  /// Fetches a single entry by id.
  Future<AuditEntry?> get(String id);

  /// Returns a snapshot of the ledger, newest first.
  ///
  /// [limit] caps the number of entries returned (default 50). [offset]
  /// skips over the N most recent entries for paging.
  Future<List<AuditEntry>> list({int limit = 50, int offset = 0});

  /// Stream of entries as they are appended or updated (e.g. undo). Emits on
  /// both [record] and [markUndone]. Replays nothing on subscription —
  /// fetch history via [list].
  Stream<AuditEntry> get changes;
}

/// Default in-memory ledger backed by a growable [List].
///
/// Entries are stored oldest-first internally but [list] returns newest-first.
class InMemoryAuditLedger extends AuditLedger {
  /// Creates an empty ledger.
  InMemoryAuditLedger();

  final List<AuditEntry> _entries = [];
  final StreamController<AuditEntry> _controller =
      StreamController<AuditEntry>.broadcast();
  int _nextId = 0;

  @override
  Future<AuditEntry> record({
    required ToolCall call,
    required ToolResult result,
    ResolvedPolicy? resolved,
    DateTime? timestamp,
    Duration executionDuration = Duration.zero,
  }) async {
    final entry = AuditEntry(
      id: (_nextId++).toString(),
      timestamp: timestamp ?? DateTime.now(),
      call: call,
      result: result,
      resolved: resolved,
      executionDuration: executionDuration,
    );
    _entries.add(entry);
    _controller.add(entry);
    return entry;
  }

  @override
  Future<AuditEntry?> markUndone(
    String id, {
    required ToolResult undoResult,
    DateTime? at,
  }) async {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index < 0) return null;
    final updated = _entries[index].markedUndone(
      at: at ?? DateTime.now(),
      result: undoResult,
    );
    _entries[index] = updated;
    _controller.add(updated);
    return updated;
  }

  @override
  Future<AuditEntry?> get(String id) async {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<List<AuditEntry>> list({int limit = 50, int offset = 0}) async {
    final total = _entries.length;
    if (offset == 0 && limit == 1) {
      return total == 0 ? const [] : [_entries.last];
    }
    final start = (total - offset).clamp(0, total);
    final end = (start - limit).clamp(0, total);
    return [for (var i = start - 1; i >= end; i--) _entries[i]];
  }

  @override
  Stream<AuditEntry> get changes => _controller.stream;

  /// Closes the [changes] stream. Call during app teardown.
  Future<void> close() => _controller.close();
}
