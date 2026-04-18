import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import '../llm/llm_adapter.dart';
import '../model_manager/model_catalog_entry.dart';
import '../model_manager/model_install_state.dart';

enum _InlineToolStatus { pending, running, succeeded, failed, canceled }

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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
        final policyDecision = await widget.mcp.getPolicyDecision(
          call.toolName,
        );
        final inlineState = _InlineToolCallState(
          call: call,
          policyDecision: policyDecision,
          toolDescription: _toolDescription(call.toolName),
          argumentsJson: _prettyJson.convert(call.arguments),
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

      setState(() {
        _result = resultJson;
        _inlineCalls[callId] = current.copyWith(
          status: result.success
              ? _InlineToolStatus.succeeded
              : _InlineToolStatus.failed,
          resultJson: resultJson,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final errorJson = _prettyJson.convert(
        ToolResult.fail('execution_failed', e.toString()).toJson(),
      );

      setState(() {
        _result = errorJson;
        _inlineCalls[callId] = current.copyWith(
          status: _InlineToolStatus.failed,
          resultJson: errorJson,
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

  Widget _buildInlineToolCard(_InlineToolCallState state) {
    final call = state.call;
    final callId = call.id;
    final canRun =
        state.status == _InlineToolStatus.pending &&
        state.policyDecision != PolicyDecision.deny;
    final canCancel = state.status == _InlineToolStatus.pending;

    return Container(
      key: ValueKey('inline-tool-call-card-$callId'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            call.toolName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(state.toolDescription),
          const SizedBox(height: 6),
          Text(
            'Policy: ${_policyLabel(state.policyDecision)}',
            key: ValueKey('inline-tool-policy-$callId'),
          ),
          Text(
            'Status: ${_statusLabel(state.status)}',
            key: ValueKey('inline-tool-status-$callId'),
          ),
          const SizedBox(height: 6),
          SelectableText(
            state.argumentsJson,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.tonal(
                key: ValueKey('inline-run-tool-call-button-$callId'),
                onPressed: canRun ? () => _executeInlineToolCall(callId) : null,
                child: const Text('Run'),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: ValueKey('inline-cancel-tool-call-button-$callId'),
                onPressed: canCancel
                    ? () => _cancelInlineToolCall(callId)
                    : null,
                child: const Text('Cancel'),
              ),
            ],
          ),
          if (state.resultJson != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              state.resultJson!,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
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
  });

  final ToolCall call;
  final PolicyDecision policyDecision;
  final String toolDescription;
  final String argumentsJson;
  final _InlineToolStatus status;
  final String? resultJson;

  _InlineToolCallState copyWith({
    _InlineToolStatus? status,
    String? resultJson,
  }) {
    return _InlineToolCallState(
      call: call,
      policyDecision: policyDecision,
      toolDescription: toolDescription,
      argumentsJson: argumentsJson,
      status: status ?? this.status,
      resultJson: resultJson ?? this.resultJson,
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
