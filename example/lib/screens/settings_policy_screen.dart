import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

class SettingsPolicyScreen extends StatefulWidget {
  const SettingsPolicyScreen({
    super.key,
    required this.mcp,
    required this.toolName,
  });

  final InAppMcp mcp;
  final String toolName;

  @override
  State<SettingsPolicyScreen> createState() => _SettingsPolicyScreenState();
}

class _SettingsPolicyScreenState extends State<SettingsPolicyScreen> {
  ToolPolicy? _current;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final policy = await widget.mcp.getToolPolicy(widget.toolName);
    if (!mounted) {
      return;
    }
    setState(() {
      _current = policy;
    });
  }

  Future<void> _set(ToolPolicy policy) async {
    if (_current == policy) {
      return;
    }
    await widget.mcp.setToolPolicy(widget.toolName, policy);
    if (!mounted) {
      return;
    }
    setState(() {
      _current = policy;
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
            const Text(
              'Tool policy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ToolPolicy>(
              segments: const [
                ButtonSegment(
                  value: ToolPolicy.auto,
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: ToolPolicy.confirm,
                  label: Text('Confirm'),
                ),
                ButtonSegment(
                  value: ToolPolicy.deny,
                  label: Text('Deny'),
                ),
              ],
              selected: {_current ?? ToolPolicy.confirm},
              onSelectionChanged: (value) {
                _set(value.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
