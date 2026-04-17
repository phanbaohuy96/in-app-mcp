import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import '../llm/llm_adapter.dart';

class ChatDemoScreen extends StatefulWidget {
  const ChatDemoScreen({
    super.key,
    required this.mcp,
    required this.llmAdapter,
  });

  final InAppMcp mcp;
  final LlmAdapter llmAdapter;

  @override
  State<ChatDemoScreen> createState() => _ChatDemoScreenState();
}

class _ChatDemoScreenState extends State<ChatDemoScreen> {
  final _controller = TextEditingController(text: 'Set alarm at 6:00 AM weekdays');
  String _result = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final call = await widget.llmAdapter.buildToolCall(_controller.text.trim());
    final policyDecision = await widget.mcp.getPolicyDecision(call.toolName);

    var confirmed = false;
    if (policyDecision == PolicyDecision.requireConfirmation && mounted) {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Confirm tool call'),
                content: Text(
                  'Run ${call.toolName} with args:\n${const JsonEncoder.withIndent('  ').convert(call.arguments)}',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Run'),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    final result = await widget.mcp.handleToolCall(call, confirmed: confirmed);

    if (!mounted) {
      return;
    }
    setState(() {
      _result = const JsonEncoder.withIndent('  ').convert(result.toJson());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Agent prompt',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _run,
              child: const Text('Run tool call'),
            ),
            const SizedBox(height: 12),
            Text(
              _result.isEmpty ? 'No result yet.' : _result,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
