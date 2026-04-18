import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import '../llm/llm_adapter.dart';
import '../model_manager/model_catalog_entry.dart';
import '../model_manager/model_install_state.dart';

enum _InlineToolStatus { pending, running, succeeded, failed, canceled }

enum _GrantChoice { onceNoGrant, grant5Min, grantSession }

class ChatDemoScreen extends StatefulWidget {
  const ChatDemoScreen({
    super.key,
    required this.mcp,
    required this.llmAdapter,
    required this.models,
    required this.states,
    required this.selectedModelId,
    required this.onSelectModel,
    this.activeModelLabel,
  });

  final InAppMcp mcp;
  final LlmAdapter llmAdapter;
  final List<ModelCatalogEntry> models;
  final Map<String, ModelInstallState> states;
  final String? selectedModelId;
  final Future<void> Function(ModelCatalogEntry model) onSelectModel;
  final String? activeModelLabel;

  @override
  State<ChatDemoScreen> createState() => _ChatDemoScreenState();
}

class _ChatDemoScreenState extends State<ChatDemoScreen> {
  static const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');
  static const int _maxChatMessages = 100;

  final _controller = TextEditingController(
    text: 'Set alarm at 6:00 AM weekdays',
  );
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final Map<String, _InlineToolCallState> _inlineCalls =
      <String, _InlineToolCallState>{};
  String _result = '';
  bool _running = false;
  StreamSubscription<AuditEntry>? _ledgerSubscription;

  @override
  void initState() {
    super.initState();
    _ledgerSubscription = widget.mcp.auditLedger?.changes.listen(
      _onLedgerEntry,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _ledgerSubscription?.cancel();
    super.dispose();
  }

  void _onLedgerEntry(AuditEntry entry) {
    final existing = _inlineCalls[entry.call.id];
    if (existing == null || existing.auditEntryId != null) return;
    if (!mounted) return;
    setState(() {
      _inlineCalls[entry.call.id] = existing.copyWith(auditEntryId: entry.id);
    });
  }

  Future<void> _appendMessage(_ChatMessage message) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(message);
      if (_messages.length > _maxChatMessages) {
        final removed = _messages.removeAt(0);
        final removedCallId = removed.inlineToolCallId;
        if (removedCallId != null) {
          _inlineCalls.remove(removedCallId);
        }
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  String _toolDescription(String toolName) {
    for (final definition in widget.mcp.tools) {
      if (definition.name == toolName) {
        return definition.description;
      }
    }
    return toolName;
  }

  String _policyLabel(PolicyDecision decision) {
    return switch (decision) {
      PolicyDecision.allow => 'Auto allow',
      PolicyDecision.requireConfirmation => 'Confirmation required',
      PolicyDecision.deny => 'Denied by policy',
    };
  }

  String _statusLabel(_InlineToolStatus status) {
    return switch (status) {
      _InlineToolStatus.pending => 'Awaiting action',
      _InlineToolStatus.running => 'Running',
      _InlineToolStatus.succeeded => 'Succeeded',
      _InlineToolStatus.failed => 'Failed',
      _InlineToolStatus.canceled => 'Canceled',
    };
  }

  IconData _toolIcon(String toolName) {
    return switch (toolName) {
      'schedule_weekday_alarm' => Icons.alarm,
      'create_calendar_event' => Icons.event,
      'open_map_directions' => Icons.directions,
      'compose_email_draft' => Icons.mail_outline,
      'echo' => Icons.repeat,
      _ => Icons.extension,
    };
  }

  Color _statusColor(_InlineToolStatus status, ColorScheme scheme) {
    return switch (status) {
      _InlineToolStatus.pending => Colors.amber.shade700,
      _InlineToolStatus.running => scheme.primary,
      _InlineToolStatus.succeeded => Colors.green.shade600,
      _InlineToolStatus.failed => scheme.error,
      _InlineToolStatus.canceled => scheme.outline,
    };
  }

  IconData _statusIcon(_InlineToolStatus status) {
    return switch (status) {
      _InlineToolStatus.pending => Icons.schedule,
      _InlineToolStatus.running => Icons.autorenew,
      _InlineToolStatus.succeeded => Icons.check_circle,
      _InlineToolStatus.failed => Icons.error,
      _InlineToolStatus.canceled => Icons.cancel,
    };
  }

  Color _policyColor(PolicyDecision decision, ColorScheme scheme) {
    return switch (decision) {
      PolicyDecision.allow => Colors.green.shade700,
      PolicyDecision.requireConfirmation => Colors.amber.shade800,
      PolicyDecision.deny => scheme.error,
    };
  }

  String _formatArgValue(Object? value) {
    if (value == null) return 'null';
    if (value is String) return '"$value"';
    if (value is bool || value is num) return value.toString();
    if (value is List) {
      return '[${value.map(_formatArgValue).join(', ')}]';
    }
    if (value is Map) {
      final entries = value.entries
          .map((e) => '${e.key}: ${_formatArgValue(e.value)}')
          .join(', ');
      return '{$entries}';
    }
    return value.toString();
  }

  Future<void> _run() async {
    if (_running) {
      return;
    }

    final prompt = _controller.text.trim();
    if (prompt.isEmpty) {
      return;
    }

    _controller.clear();
    await _appendMessage(_ChatMessage.user(prompt));

    setState(() {
      _running = true;
    });

    try {
      final turn = await widget.llmAdapter.buildTurn(prompt);
      final call = turn.toolCall;

      if (call == null) {
        await _appendMessage(_ChatMessage.assistant(turn.message));
      } else {
        final (policyDecision, preview) = await (
          widget.mcp.getPolicyDecision(call.toolName),
          widget.mcp
              .previewToolCall(call)
              .then<Preview?>((p) => p, onError: (_) => null),
        ).wait;
        final inlineState = _InlineToolCallState(
          call: call,
          policyDecision: policyDecision,
          toolDescription: _toolDescription(call.toolName),
          argumentsJson: _prettyJson.convert(call.arguments),
          preview: preview,
        );

        await _appendMessage(
          _ChatMessage.assistant(turn.message, inlineToolCallId: call.id),
        );

        if (!mounted) {
          return;
        }
        setState(() {
          _inlineCalls[call.id] = inlineState;
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      final errorJson = _prettyJson.convert(
        ToolResult.fail('proposal_failed', e.toString()).toJson(),
      );

      setState(() {
        _result = errorJson;
      });

      await _appendMessage(_ChatMessage.assistant(errorJson));
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _executeInlineToolCall(String callId) async {
    final current = _inlineCalls[callId];
    if (current == null) {
      return;
    }
    if (current.status != _InlineToolStatus.pending) {
      return;
    }
    if (current.policyDecision == PolicyDecision.deny) {
      return;
    }

    setState(() {
      _inlineCalls[callId] = current.copyWith(
        status: _InlineToolStatus.running,
      );
    });

    try {
      final result = await widget.mcp.handleToolCall(
        current.call,
        confirmed: true,
      );
      final resultJson = _prettyJson.convert(result.toJson());

      if (!mounted) {
        return;
      }

      // _onLedgerEntry will attach auditEntryId when the ledger emits.
      setState(() {
        _result = resultJson;
        final latest = _inlineCalls[callId] ?? current;
        _inlineCalls[callId] = latest.copyWith(
          status: result.success
              ? _InlineToolStatus.succeeded
              : _InlineToolStatus.failed,
          resultJson: resultJson,
          result: result,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final errorResult = ToolResult.fail('execution_failed', e.toString());
      final errorJson = _prettyJson.convert(errorResult.toJson());

      setState(() {
        _result = errorJson;
        _inlineCalls[callId] = current.copyWith(
          status: _InlineToolStatus.failed,
          resultJson: errorJson,
          result: errorResult,
        );
      });
    }
  }

  void _cancelInlineToolCall(String callId) {
    final current = _inlineCalls[callId];
    if (current == null) {
      return;
    }
    if (current.status != _InlineToolStatus.pending) {
      return;
    }

    setState(() {
      _inlineCalls[callId] = current.copyWith(
        status: _InlineToolStatus.canceled,
      );
    });
  }

  Future<void> _onGrantChoice(String callId, _GrantChoice choice) async {
    final current = _inlineCalls[callId];
    if (current == null) return;
    if (current.status != _InlineToolStatus.pending) return;
    if (current.policyDecision == PolicyDecision.deny) return;

    final toolName = current.call.toolName;
    switch (choice) {
      case _GrantChoice.onceNoGrant:
        break;
      case _GrantChoice.grant5Min:
        await widget.mcp.grantFor(toolName, const Duration(minutes: 5));
        break;
      case _GrantChoice.grantSession:
        await widget.mcp.grantUntilCleared(toolName);
        break;
    }
    await _executeInlineToolCall(callId);
  }

  Future<void> _undoInlineToolCall(String callId) async {
    final current = _inlineCalls[callId];
    if (current == null) return;
    final entryId = current.auditEntryId;
    if (entryId == null || current.undone || current.undoing) return;

    setState(() {
      _inlineCalls[callId] = current.copyWith(undoing: true);
    });

    final undoResult = await widget.mcp.undoFromLedger(entryId);

    if (!mounted) return;
    setState(() {
      _inlineCalls[callId] = current.copyWith(
        undoing: false,
        undoResult: undoResult,
      );
    });
  }

  Widget _buildInlineToolCard(_InlineToolCallState state) {
    final call = state.call;
    final callId = call.id;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canRun =
        state.status == _InlineToolStatus.pending &&
        state.policyDecision != PolicyDecision.deny;
    final canCancel = state.status == _InlineToolStatus.pending;
    final statusColor = _statusColor(state.status, scheme);
    final policyColor = _policyColor(state.policyDecision, scheme);
    final result = state.result;

    return Container(
      key: ValueKey('inline-tool-call-card-$callId'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _toolIcon(call.toolName),
                  size: 20,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.toolName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      state.toolDescription,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(
                keyValue: ValueKey('inline-tool-status-$callId'),
                icon: _statusIcon(state.status),
                label: _statusLabel(state.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PolicyChip(
            keyValue: ValueKey('inline-tool-policy-$callId'),
            label: _policyLabel(state.policyDecision),
            color: policyColor,
          ),
          if (state.preview != null) ...[
            const SizedBox(height: 12),
            _SectionHeader(label: 'Preview', scheme: scheme),
            const SizedBox(height: 4),
            Container(
              key: ValueKey('inline-tool-preview-$callId'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.preview_outlined,
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          state.preview!.summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final warning in state.preview!.warnings) ...[
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            warning.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (call.arguments.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionHeader(label: 'Arguments', scheme: scheme),
            const SizedBox(height: 4),
            ...call.arguments.entries.map(
              (entry) => _KeyValueRow(
                keyText: entry.key,
                valueText: _formatArgValue(entry.value),
                scheme: scheme,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                key: ValueKey('inline-run-tool-call-button-$callId'),
                onPressed: canRun ? () => _executeInlineToolCall(callId) : null,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Run'),
              ),
              const SizedBox(width: 8),
              if (canRun)
                PopupMenuButton<_GrantChoice>(
                  key: ValueKey('inline-grant-menu-$callId'),
                  tooltip: 'Grant and run',
                  icon: const Icon(Icons.flash_on, size: 18),
                  onSelected: (choice) => _onGrantChoice(callId, choice),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _GrantChoice.onceNoGrant,
                      child: Text('Run once'),
                    ),
                    PopupMenuItem(
                      value: _GrantChoice.grant5Min,
                      child: Text('Run + allow 5 min'),
                    ),
                    PopupMenuItem(
                      value: _GrantChoice.grantSession,
                      child: Text('Run + allow for session'),
                    ),
                  ],
                ),
              const Spacer(),
              TextButton(
                key: ValueKey('inline-cancel-tool-call-button-$callId'),
                onPressed: canCancel
                    ? () => _cancelInlineToolCall(callId)
                    : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green.shade600 : scheme.error,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    result.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (result.data.isNotEmpty) ...[
              const SizedBox(height: 8),
              _SectionHeader(label: 'Result', scheme: scheme),
              const SizedBox(height: 4),
              ...result.data.entries.map(
                (entry) => _KeyValueRow(
                  keyText: entry.key,
                  valueText: _formatArgValue(entry.value),
                  scheme: scheme,
                ),
              ),
            ],
            if (result.success && state.auditEntryId != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: ValueKey('inline-undo-button-$callId'),
                    onPressed: (state.undone || state.undoing)
                        ? null
                        : () => _undoInlineToolCall(callId),
                    icon: state.undoing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.undo, size: 16),
                    label: Text(state.undone ? 'Undone' : 'Undo'),
                  ),
                  if (state.undoResult != null &&
                      !state.undoResult!.success) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.undoResult!.message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelLabel = (widget.activeModelLabel ?? '').trim();
    final downloadedModels = widget.models
        .where((model) => widget.states[model.id]?.isDownloaded == true)
        .toList(growable: false);

    final selectedModelId =
        downloadedModels.any((m) => m.id == widget.selectedModelId)
        ? widget.selectedModelId
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (downloadedModels.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: const ValueKey('chat-model-selector'),
                  initialValue: selectedModelId,
                  decoration: const InputDecoration(
                    labelText: 'Selected model',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Choose model'),
                  items: downloadedModels
                      .map(
                        (model) => DropdownMenuItem<String>(
                          value: model.id,
                          child: Text(model.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    for (final model in downloadedModels) {
                      if (model.id == value) {
                        await widget.onSelectModel(model);
                        return;
                      }
                    }
                  },
                )
              else
                const Text(
                  'No downloaded model available. Open settings to download one.',
                ),
              const SizedBox(height: 8),
              Text(
                'Adapter: ${widget.llmAdapter.id}',
                key: const ValueKey('adapter-label'),
              ),
              Text(
                modelLabel.isEmpty
                    ? 'Active model: none'
                    : 'Active model: $modelLabel',
                key: const ValueKey('active-model-label'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            key: const ValueKey('chat-message-list'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.isEmpty ? 1 : _messages.length,
            itemBuilder: (context, index) {
              if (_messages.isEmpty) {
                return const Text('Ask the agent to run a tool call.');
              }

              final message = _messages[index];
              final alignment = message.fromUser
                  ? Alignment.centerRight
                  : Alignment.centerLeft;
              final color = message.fromUser
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest;

              final inlineState = message.inlineToolCallId == null
                  ? null
                  : _inlineCalls[message.inlineToolCallId!];

              return Align(
                alignment: alignment,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: message.fromUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(message.text),
                      ),
                      if (inlineState != null)
                        _buildInlineToolCard(inlineState),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_running) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('agent-prompt-input'),
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Agent prompt',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('run-tool-call-button'),
                onPressed: _running ? null : _run,
                child: const Text('Send'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            _result.isEmpty ? 'No result yet.' : _result,
            key: const ValueKey('tool-call-result'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}

class _InlineToolCallState {
  const _InlineToolCallState({
    required this.call,
    required this.policyDecision,
    required this.toolDescription,
    required this.argumentsJson,
    this.status = _InlineToolStatus.pending,
    this.resultJson,
    this.result,
    this.preview,
    this.auditEntryId,
    this.undoing = false,
    this.undoResult,
  });

  final ToolCall call;
  final PolicyDecision policyDecision;
  final String toolDescription;
  final String argumentsJson;
  final _InlineToolStatus status;
  final String? resultJson;
  final ToolResult? result;
  final Preview? preview;
  final String? auditEntryId;
  final bool undoing;
  final ToolResult? undoResult;

  bool get undone => undoResult?.success == true;

  _InlineToolCallState copyWith({
    _InlineToolStatus? status,
    String? resultJson,
    ToolResult? result,
    Preview? preview,
    String? auditEntryId,
    bool? undoing,
    ToolResult? undoResult,
  }) {
    return _InlineToolCallState(
      call: call,
      policyDecision: policyDecision,
      toolDescription: toolDescription,
      argumentsJson: argumentsJson,
      status: status ?? this.status,
      resultJson: resultJson ?? this.resultJson,
      result: result ?? this.result,
      preview: preview ?? this.preview,
      auditEntryId: auditEntryId ?? this.auditEntryId,
      undoing: undoing ?? this.undoing,
      undoResult: undoResult ?? this.undoResult,
    );
  }
}

class _ChatMessage {
  const _ChatMessage.user(this.text) : fromUser = true, inlineToolCallId = null;

  const _ChatMessage.assistant(this.text, {this.inlineToolCallId})
    : fromUser = false;

  final String text;
  final bool fromUser;
  final String? inlineToolCallId;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.keyValue,
    required this.icon,
    required this.label,
    required this.color,
  });

  final Key keyValue;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: keyValue,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyChip extends StatelessWidget {
  const _PolicyChip({
    required this.keyValue,
    required this.label,
    required this.color,
  });

  final Key keyValue;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: keyValue,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.scheme});

  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.keyText,
    required this.valueText,
    required this.scheme,
  });

  final String keyText;
  final String valueText;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: scheme.onSurface,
          ),
          children: [
            TextSpan(
              text: '$keyText: ',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: valueText),
          ],
        ),
      ),
    );
  }
}
