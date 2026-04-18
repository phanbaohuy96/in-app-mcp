import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import 'agent_tools/tool_catalog.dart';
import 'llm/gemma_adapter.dart';
import 'llm/llm_adapter.dart';
import 'llm/llm_adapter_mode.dart';
import 'llm/mock_llm_adapter.dart';
import 'model_manager/model_catalog_entry.dart';
import 'model_manager/model_channel_client.dart';
import 'model_manager/model_manager_controller.dart';
import 'screens/audit_timeline_screen.dart';
import 'screens/chat_demo_screen.dart';
import 'screens/settings_screen.dart';

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
  late final ToolCatalog _toolCatalog;
  late final ModelManagerController _modelManager;
  late final LlmAdapterMode _requestedAdapterMode;
  late LlmAdapter _llmAdapter;

  bool _pollingModels = false;

  @override
  void initState() {
    super.initState();
    _mcp = InAppMcp(defaultPolicy: ToolPolicy.confirm);

    _toolCatalog = ToolCatalog();
    _toolCatalog.register(_mcp);

    _requestedAdapterMode = LlmAdapterModeConfig.fromEnvironment();
    _modelManager = ModelManagerController(
      channelClient: const ModelChannelClient(),
    );
    _llmAdapter = MockLlmAdapter();

    _initializeModelManager();
  }

  @override
  void dispose() {
    _modelManager.dispose();
    _llmAdapter.dispose();
    super.dispose();
  }

  Future<void> _initializeModelManager() async {
    await _modelManager.initialize();
    if (!mounted) {
      return;
    }
    setState(_updateAdapterIfChanged);
  }

  String _effectiveModelPath() {
    final selectedPath = (_modelManager.selectedModelPath ?? '').trim();
    const fallbackPath = String.fromEnvironment(
      'GEMMA_MODEL_PATH',
      defaultValue: '',
    );
    return selectedPath.isNotEmpty ? selectedPath : fallbackPath.trim();
  }

  bool _shouldUseGemma(LlmAdapterMode mode) {
    return mode == LlmAdapterMode.gemma4 || _effectiveModelPath().isNotEmpty;
  }

  String _adapterIdFor(LlmAdapterMode mode) {
    if (_shouldUseGemma(mode)) {
      final modelPath = _effectiveModelPath();
      if (modelPath.isEmpty) {
        return 'mock';
      }
      return GemmaAdapter.adapterIdForPath(modelPath);
    }
    return 'mock';
  }

  LlmAdapter _buildAdapter(LlmAdapterMode mode) {
    if (_shouldUseGemma(mode)) {
      final modelPath = _effectiveModelPath();
      if (modelPath.isNotEmpty) {
        return GemmaAdapter(
          modelPath: modelPath,
          toolSchema: _buildToolSchema(_toolCatalog.definitions),
          deterministicMode: const bool.fromEnvironment(
            'E2E_MODE',
            defaultValue: false,
          ),
        );
      }
    }
    return MockLlmAdapter();
  }

  String _buildToolSchema(List<ToolDefinition> definitions) {
    return jsonEncode({
      'tools': definitions
          .map(
            (definition) => {
              'name': definition.name,
              'description': definition.description,
              'requiredArguments': definition.requiredArguments.toList()
                ..sort(),
              'argumentTypes': {
                for (final entry in definition.argumentTypes.entries)
                  entry.key: entry.value.name,
              },
            },
          )
          .toList(),
    });
  }

  void _updateAdapterIfChanged() {
    final current = _llmAdapter;
    final nextId = _adapterIdFor(_requestedAdapterMode);
    if (current.id == nextId) {
      return;
    }

    final next = _buildAdapter(_requestedAdapterMode);
    _llmAdapter = next;
    unawaited(current.dispose());
  }

  Future<void> _runModelAction(
    Future<void> Function() action, {
    bool pollAfter = false,
  }) async {
    await action();
    if (!mounted) {
      return;
    }
    setState(_updateAdapterIfChanged);
    if (pollAfter) {
      _maybePollUntilDownloadsSettle();
    }
  }

  Future<void> _refreshModels() async {
    await _runModelAction(_modelManager.refreshStatuses, pollAfter: true);
  }

  Future<void> _startDownload(ModelCatalogEntry model) async {
    await _runModelAction(
      () => _modelManager.startDownload(model),
      pollAfter: true,
    );
  }

  Future<void> _cancelDownload(ModelCatalogEntry model) async {
    await _runModelAction(
      () => _modelManager.cancelDownload(model),
      pollAfter: true,
    );
  }

  Future<void> _maybePollUntilDownloadsSettle() async {
    if (_pollingModels) {
      return;
    }
    if (!_modelManager.states.values.any((state) => state.isDownloading)) {
      return;
    }

    _pollingModels = true;
    try {
      while (mounted &&
          _modelManager.states.values.any((state) => state.isDownloading)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final previousStates = _modelManager.states;
        final previousSelection = _modelManager.selectedModelId;
        await _modelManager.refreshStatuses();
        if (!mounted) {
          return;
        }
        final statesChanged = !mapEquals(previousStates, _modelManager.states);
        final selectionChanged =
            previousSelection != _modelManager.selectedModelId;
        if (statesChanged || selectionChanged) {
          setState(_updateAdapterIfChanged);
        }
      }
    } finally {
      _pollingModels = false;
    }
  }

  Future<void> _deleteModel(ModelCatalogEntry model) async {
    await _runModelAction(() => _modelManager.deleteModel(model));
  }

  Future<void> _selectModel(ModelCatalogEntry model) async {
    await _runModelAction(() => _modelManager.selectModel(model.id));
  }

  @override
  Widget build(BuildContext context) {
    final shouldPreferGemma = _shouldUseGemma(_requestedAdapterMode);
    final usingFallback =
        shouldPreferGemma && _llmAdapter.mode != LlmAdapterMode.gemma4;

    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('in_app_mcp example'),
              actions: [
                IconButton(
                  key: const ValueKey('open-audit-timeline-button'),
                  icon: const Icon(Icons.history),
                  tooltip: 'Audit timeline',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AuditTimelineScreen(mcp: _mcp),
                      ),
                    );
                  },
                ),
                IconButton(
                  key: const ValueKey('open-settings-button'),
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsScreen(
                          mcp: _mcp,
                          tools: _toolCatalog.definitions,
                          modelManager: _modelManager,
                          onRefresh: _refreshModels,
                          onDownload: _startDownload,
                          onCancel: _cancelDownload,
                          onDelete: _deleteModel,
                          onSelect: _selectModel,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                if (usingFallback)
                  const Material(
                    color: Colors.amberAccent,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Gemma requested but no downloaded selected model. Using mock adapter.',
                      ),
                    ),
                  ),
                Expanded(
                  child: ChatDemoScreen(
                    mcp: _mcp,
                    llmAdapter: _llmAdapter,
                    models: _modelManager.catalog,
                    states: _modelManager.states,
                    selectedModelId: _modelManager.selectedModelId,
                    onSelectModel: _selectModel,
                    activeModelLabel: _modelManager.selectedModelName,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
