import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import 'agent_tools/tool_catalog.dart';
import 'llm/mock_llm_adapter.dart';
import 'screens/chat_demo_screen.dart';
import 'screens/settings_policy_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final InAppMcp _mcp;

  @override
  void initState() {
    super.initState();
    _mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);
    ToolCatalog().register(_mcp);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('in_app_mcp example')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsPolicyScreen(
              mcp: _mcp,
              toolName: 'schedule_weekday_alarm',
            ),
            const SizedBox(height: 12),
            ChatDemoScreen(
              mcp: _mcp,
              llmAdapter: MockLlmAdapter(),
            ),
          ],
        ),
      ),
    );
  }
}
