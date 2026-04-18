import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'model_catalog_entry.dart';
import 'model_channel_client.dart';
import 'model_install_state.dart';

class ModelManagerController {
  ModelManagerController({
    required this.channelClient,
    SharedPreferences? preferences,
  }) : _preferences = preferences;

  static const _selectedKey = 'selected_model_id';
  final ModelChannelClient channelClient;
  SharedPreferences? _preferences;

  List<ModelCatalogEntry> _catalog = const [];
  Map<String, ModelInstallState> _states = const {};
  String? _selectedModelId;

  List<ModelCatalogEntry> get catalog => _catalog;
  Map<String, ModelInstallState> get states => _states;
  String? get selectedModelId => _selectedModelId;

  ModelCatalogEntry? get selectedModel {
    final id = _selectedModelId;
    if (id == null) {
      return null;
    }
    for (final model in _catalog) {
      if (model.id == id) {
        return model;
      }
    }
    return null;
  }

  String? get selectedModelPath {
    final selected = selectedModel;
    if (selected == null) {
      return null;
    }
    return _states[selected.id]?.localPath;
  }

  String? get selectedModelName => selectedModel?.name;

  Future<void> initialize() async {
    _catalog = await _loadCatalog();
    try {
      _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      _preferences = null;
    }
    _selectedModelId = _preferences?.getString(_selectedKey);

    if (_catalog.isNotEmpty) {
      await refreshStatuses();
      _ensureValidSelection();
      await _persistSelection();
    }
  }

  Future<void> dispose() async {}

  Future<void> refreshStatuses() async {
    if (_catalog.isEmpty) {
      return;
    }

    final statuses = await Future.wait(
      _catalog.map(
        (model) async => (model.id, await channelClient.getStatus(model)),
      ),
    );

    final entries = <String, ModelInstallState>{
      for (final item in statuses) item.$1: item.$2,
    };

    final previousSelection = _selectedModelId;
    _states = entries;
    _ensureValidSelection();

    if (previousSelection != _selectedModelId) {
      await _persistSelection();
    }
  }

  Future<void> startDownload(ModelCatalogEntry entry) async {
    await channelClient.startDownload(entry);
    await refreshStatuses();
  }

  Future<void> cancelDownload(ModelCatalogEntry entry) async {
    await channelClient.cancelDownload(entry);
    await refreshStatuses();
  }

  Future<void> deleteModel(ModelCatalogEntry entry) async {
    await channelClient.deleteModel(entry);
    await refreshStatuses();
    if (_selectedModelId == entry.id) {
      _selectedModelId = null;
      _ensureValidSelection();
      await _persistSelection();
    }
  }

  Future<void> selectModel(String modelId) async {
    _selectedModelId = modelId;
    _ensureValidSelection();
    await _persistSelection();
  }

  void _ensureValidSelection() {
    final selected = _selectedModelId;
    if (selected != null) {
      final selectedState = _states[selected];
      if (selectedState != null && selectedState.isDownloaded) {
        return;
      }
    }

    for (final model in _catalog) {
      final state = _states[model.id];
      if (state != null && state.isDownloaded) {
        _selectedModelId = model.id;
        return;
      }
    }

    _selectedModelId = null;
  }

  Future<void> _persistSelection() async {
    final prefs = _preferences;
    if (prefs == null) {
      return;
    }

    final selected = _selectedModelId;
    if (selected == null) {
      await prefs.remove(_selectedKey);
    } else {
      await prefs.setString(_selectedKey, selected);
    }
  }

  Future<List<ModelCatalogEntry>> _loadCatalog() async {
    final String raw;
    try {
      raw = await rootBundle.loadString('assets/model_catalog.json');
    } catch (_) {
      return const [
        ModelCatalogEntry(
          id: 'gemma4_e2b_it',
          name: 'Gemma 4 E2B (Instruct)',
          modelId: 'litert-community/gemma-4-E2B-it-litert-lm',
          modelFile: 'gemma-4-E2B-it.litertlm',
          sizeInBytes: 2583085056,
          description:
              'Public Gemma 4 E2B model for on-device LiteRT-LM inference.',
          recommended: true,
          downloadUrl:
              'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
        ),
        ModelCatalogEntry(
          id: 'gemma4_e4b_it',
          name: 'Gemma 4 E4B (Instruct)',
          modelId: 'litert-community/gemma-4-E4B-it-litert-lm',
          modelFile: 'gemma-4-E4B-it.litertlm',
          sizeInBytes: 3654467584,
          description:
              'Larger Gemma 4 variant with higher quality and memory usage.',
          recommended: false,
          downloadUrl:
              'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
        ),
      ];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return const [];
    }

    final models = decoded['models'];
    if (models is! List) {
      return const [];
    }

    return models
        .whereType<Map>()
        .map(
          (item) => ModelCatalogEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .where(
          (item) =>
              item.id.trim().isNotEmpty &&
              item.modelId.trim().isNotEmpty &&
              item.modelFile.trim().isNotEmpty,
        )
        .toList(growable: false);
  }
}
