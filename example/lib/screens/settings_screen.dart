import 'package:flutter/material.dart';
import 'package:in_app_mcp/in_app_mcp.dart';

import '../model_manager/model_catalog_entry.dart';
import '../model_manager/model_install_state.dart';
import '../model_manager/model_manager_controller.dart';
import 'settings_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.mcp,
    required this.tools,
    required this.modelManager,
    required this.onRefresh,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onSelect,
  });

  final InAppMcp mcp;
  final List<ToolDefinition> tools;
  final ModelManagerController modelManager;
  final Future<void> Function() onRefresh;
  final Future<void> Function(ModelCatalogEntry model) onDownload;
  final Future<void> Function(ModelCatalogEntry model) onCancel;
  final Future<void> Function(ModelCatalogEntry model) onDelete;
  final Future<void> Function(ModelCatalogEntry model) onSelect;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: () => _run(widget.onRefresh),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ModelManagerCard(
              models: widget.modelManager.catalog,
              states: widget.modelManager.states,
              selectedModelId: widget.modelManager.selectedModelId,
              onDownload: (model) => _run(() => widget.onDownload(model)),
              onCancel: (model) => _run(() => widget.onCancel(model)),
              onDelete: (model) => _run(() => widget.onDelete(model)),
              onSelect: (model) => _run(() => widget.onSelect(model)),
            ),
            const SizedBox(height: 12),
            SettingsPolicyScreen(mcp: widget.mcp, tools: widget.tools),
          ],
        ),
      ),
    );
  }
}

class _ModelManagerCard extends StatelessWidget {
  const _ModelManagerCard({
    required this.models,
    required this.states,
    required this.selectedModelId,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onSelect,
  });

  final List<ModelCatalogEntry> models;
  final Map<String, ModelInstallState> states;
  final String? selectedModelId;
  final Future<void> Function(ModelCatalogEntry model) onDownload;
  final Future<void> Function(ModelCatalogEntry model) onCancel;
  final Future<void> Function(ModelCatalogEntry model) onDelete;
  final Future<void> Function(ModelCatalogEntry model) onSelect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Models', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final model in models)
              _ModelRow(
                model: model,
                state:
                    states[model.id] ??
                    const ModelInstallState(
                      phase: ModelInstallPhase.notDownloaded,
                    ),
                selected: selectedModelId == model.id,
                onDownload: onDownload,
                onCancel: onCancel,
                onDelete: onDelete,
                onSelect: onSelect,
              ),
          ],
        ),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.state,
    required this.selected,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onSelect,
  });

  final ModelCatalogEntry model;
  final ModelInstallState state;
  final bool selected;
  final Future<void> Function(ModelCatalogEntry model) onDownload;
  final Future<void> Function(ModelCatalogEntry model) onCancel;
  final Future<void> Function(ModelCatalogEntry model) onDelete;
  final Future<void> Function(ModelCatalogEntry model) onSelect;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (state.phase) {
      ModelInstallPhase.notDownloaded => 'Not downloaded',
      ModelInstallPhase.downloading =>
        'Downloading ${(state.progress * 100).toStringAsFixed(1)}%',
      ModelInstallPhase.downloaded => 'Downloaded',
      ModelInstallPhase.failed => state.error ?? 'Failed',
    };

    return Container(
      key: ValueKey('model-row-${model.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (model.recommended) const Chip(label: Text('Recommended')),
            ],
          ),
          Text(subtitle, key: ValueKey('model-status-${model.id}')),
          if (state.isDownloading)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                key: ValueKey('model-progress-${model.id}'),
                value: state.totalBytes > 0 ? state.progress : null,
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (!state.isDownloaded && !state.isDownloading)
                OutlinedButton(
                  key: ValueKey('model-download-${model.id}'),
                  onPressed: () => onDownload(model),
                  child: const Text('Download'),
                ),
              if (state.isDownloading)
                OutlinedButton(
                  key: ValueKey('model-cancel-${model.id}'),
                  onPressed: () => onCancel(model),
                  child: const Text('Cancel'),
                ),
              if (state.isDownloaded)
                FilledButton(
                  key: ValueKey('model-select-${model.id}'),
                  onPressed: selected ? null : () => onSelect(model),
                  child: Text(selected ? 'Selected' : 'Select'),
                ),
              if (state.isDownloaded)
                TextButton(
                  key: ValueKey('model-delete-${model.id}'),
                  onPressed: () => onDelete(model),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
