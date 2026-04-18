import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

/// Browses `InAppMcp.auditLedger` newest-first, with a per-entry undo button
/// for successful entries whose tool registered a [ToolUndoer].
class AuditTimelineScreen extends StatefulWidget {
  const AuditTimelineScreen({super.key, required this.mcp});

  final InAppMcp mcp;

  @override
  State<AuditTimelineScreen> createState() => _AuditTimelineScreenState();
}

class _AuditTimelineScreenState extends State<AuditTimelineScreen> {
  StreamSubscription<AuditEntry>? _subscription;
  List<AuditEntry> _entries = const [];
  final Set<String> _undoing = <String>{};

  AuditLedger? get _ledger => widget.mcp.auditLedger;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = _ledger?.changes.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final ledger = _ledger;
    if (ledger == null) return;
    final entries = await ledger.list(limit: 100);
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  Future<void> _undo(AuditEntry entry) async {
    if (_undoing.contains(entry.id)) return;
    setState(() => _undoing.add(entry.id));
    await widget.mcp.undoFromLedger(entry.id);
    // changes stream fires markUndone → _refresh is triggered via subscription.
    if (!mounted) return;
    setState(() => _undoing.remove(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit timeline')),
      body: _ledger == null
          ? const Center(child: Text('Audit ledger is disabled.'))
          : _entries.isEmpty
          ? const Center(child: Text('No tool calls recorded yet.'))
          : ListView.separated(
              key: const ValueKey('audit-timeline-list'),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return _AuditEntryTile(
                  entry: entry,
                  undoing: _undoing.contains(entry.id),
                  onUndo: () => _undo(entry),
                  scheme: scheme,
                  theme: theme,
                );
              },
            ),
    );
  }
}

class _AuditEntryTile extends StatelessWidget {
  const _AuditEntryTile({
    required this.entry,
    required this.undoing,
    required this.onUndo,
    required this.scheme,
    required this.theme,
  });

  final AuditEntry entry;
  final bool undoing;
  final VoidCallback onUndo;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final succeeded = entry.result.success;
    final color = entry.undone
        ? scheme.outline
        : (succeeded ? Colors.green.shade600 : scheme.error);
    final icon = entry.undone
        ? Icons.history
        : (succeeded ? Icons.check_circle : Icons.error);
    final canUndo = succeeded && !entry.undone;

    return ListTile(
      key: ValueKey('audit-entry-${entry.id}'),
      leading: Icon(icon, color: color),
      title: Text(
        entry.call.toolName,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.result.message),
          Text(
            _formatTimestamp(entry.timestamp),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (entry.undone)
            Text(
              'Undone',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
      trailing: canUndo
          ? TextButton.icon(
              key: ValueKey('audit-undo-${entry.id}'),
              onPressed: undoing ? null : onUndo,
              icon: undoing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo, size: 16),
              label: const Text('Undo'),
            )
          : null,
    );
  }

  String _formatTimestamp(DateTime t) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final date = '${t.year}-${pad(t.month)}-${pad(t.day)}';
    final time = '${pad(t.hour)}:${pad(t.minute)}:${pad(t.second)}';
    return '$date $time';
  }
}
