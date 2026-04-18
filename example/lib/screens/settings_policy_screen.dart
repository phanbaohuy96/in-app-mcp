import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

class SettingsPolicyScreen extends StatefulWidget {
  const SettingsPolicyScreen({
    super.key,
    required this.mcp,
    required this.tools,
  });

  final InAppMcp mcp;
  final List<ToolDefinition> tools;

  @override
  State<SettingsPolicyScreen> createState() => _SettingsPolicyScreenState();
}

class _SettingsPolicyScreenState extends State<SettingsPolicyScreen> {
  Map<String, ToolPolicy> _policies = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await Future.wait(
      widget.tools.map((tool) async {
        final policy = await widget.mcp.getToolPolicy(tool.name);
        return (tool.name, policy);
      }),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _policies = {for (final entry in entries) entry.$1: entry.$2};
      _loading = false;
    });
  }

  Future<void> _set(String toolName, ToolPolicy policy) async {
    final current = _policies[toolName] ?? ToolPolicy.confirm;
    if (current == policy) {
      return;
    }

    await widget.mcp.setToolPolicy(toolName, policy);
    if (!mounted) {
      return;
    }

    setState(() {
      _policies = {..._policies, toolName: policy};
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
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: const ValueKey('tool-policy-table'),
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Auto')),
                    DataColumn(label: Text('Confirm')),
                    DataColumn(label: Text('Deny')),
                  ],
                  rows: widget.tools
                      .map(
                        (tool) => DataRow(
                          cells: [
                            DataCell(
                              KeyedSubtree(
                                key: ValueKey('tool-policy-row-${tool.name}'),
                                child: Text(tool.name),
                              ),
                            ),
                            DataCell(
                              Checkbox(
                                key: ValueKey('tool-policy-${tool.name}-auto'),
                                value:
                                    (_policies[tool.name] ??
                                        ToolPolicy.confirm) ==
                                    ToolPolicy.auto,
                                onChanged: (_) =>
                                    _set(tool.name, ToolPolicy.auto),
                              ),
                            ),
                            DataCell(
                              Checkbox(
                                key: ValueKey(
                                  'tool-policy-${tool.name}-confirm',
                                ),
                                value:
                                    (_policies[tool.name] ??
                                        ToolPolicy.confirm) ==
                                    ToolPolicy.confirm,
                                onChanged: (_) =>
                                    _set(tool.name, ToolPolicy.confirm),
                              ),
                            ),
                            DataCell(
                              Checkbox(
                                key: ValueKey('tool-policy-${tool.name}-deny'),
                                value:
                                    (_policies[tool.name] ??
                                        ToolPolicy.confirm) ==
                                    ToolPolicy.deny,
                                onChanged: (_) =>
                                    _set(tool.name, ToolPolicy.deny),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
