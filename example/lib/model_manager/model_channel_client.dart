import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';

import 'model_catalog_entry.dart';
import 'model_install_state.dart';

class ModelChannelClient {
  const ModelChannelClient();

  static const _preloadedModelPath = String.fromEnvironment(
    'GEMMA_MODEL_PATH',
    defaultValue: '',
  );
  static const _preloadedModelDir = String.fromEnvironment(
    'MODEL_CACHE_DIR',
    defaultValue: '',
  );

  static final Map<String, _FallbackDownloadState> _states = {};
  static final Map<String, HttpClientRequest> _requests = {};
  static final HttpClient _httpClient = HttpClient();

  Future<List<Map<String, dynamic>>> listModels() async {
    final entries = <Map<String, dynamic>>[];
    for (final item in _states.entries) {
      final state = item.value;
      if (state.status == _statusDownloaded && state.localPath != null) {
        entries.add({
          'storageKey': item.key,
          'status': state.status,
          'localPath': state.localPath,
          'downloadedBytes': state.downloadedBytes,
          'totalBytes': state.totalBytes,
        });
      }
    }
    return entries;
  }

  Future<ModelInstallState> getStatus(ModelCatalogEntry entry) async {
    final state = await _statusFor(entry);
    return ModelInstallState.fromMap({
      'status': state.status,
      'downloadedBytes': state.downloadedBytes,
      'totalBytes': state.totalBytes,
      'localPath': state.localPath,
      'error': state.error,
    });
  }

  Future<void> startDownload(ModelCatalogEntry entry) async {
    await _startDownload(entry);
  }

  Future<void> cancelDownload(ModelCatalogEntry entry) async {
    final request = _requests.remove(entry.storageKey);
    if (request != null) {
      request.abort();
    }

    final target = await _fileFor(entry);
    final partial = File('${target.path}.partial');
    if (await partial.exists()) {
      await partial.delete();
    }

    _states[entry.storageKey] = const _FallbackDownloadState(
      status: _statusNotDownloaded,
      downloadedBytes: 0,
      totalBytes: 0,
    );
  }

  Future<void> deleteModel(ModelCatalogEntry entry) async {
    final request = _requests.remove(entry.storageKey);
    if (request != null) {
      request.abort();
    }

    final target = await _fileFor(entry);
    if (await target.exists()) {
      await target.delete();
    }
    final partial = File('${target.path}.partial');
    if (await partial.exists()) {
      await partial.delete();
    }
    _states.remove(entry.storageKey);
  }

  Future<void> _startDownload(ModelCatalogEntry entry) async {
    final existing = _states[entry.storageKey];
    if (existing != null && existing.status == _statusDownloading) {
      return;
    }

    final target = await _fileFor(entry);
    final partial = File('${target.path}.partial');
    await partial.parent.create(recursive: true);

    final url = (entry.downloadUrl ?? '').trim().isNotEmpty
        ? entry.downloadUrl!.trim()
        : 'https://huggingface.co/${entry.modelId}/resolve/main/${entry.modelFile}?download=true';

    final totalBytes = entry.sizeInBytes > 0 ? entry.sizeInBytes : 0;
    _states[entry.storageKey] = _FallbackDownloadState(
      status: _statusDownloading,
      downloadedBytes: 0,
      totalBytes: totalBytes,
      localPath: null,
      error: null,
    );

    unawaited(
      Future<void>(() async {
        try {
          final request = await _httpClient.getUrl(Uri.parse(url));
          _requests[entry.storageKey] = request;
          final response = await request.close();

          if (response.statusCode < 200 || response.statusCode >= 300) {
            throw StateError(
              'Download failed with HTTP ${response.statusCode}',
            );
          }

          final sink = partial.openWrite();
          var downloaded = 0;
          var lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

          try {
            await for (final chunk in response) {
              sink.add(chunk);
              downloaded += chunk.length;

              final now = DateTime.now();
              if (now.difference(lastEmit).inMilliseconds >= 300) {
                _states[entry.storageKey] = _FallbackDownloadState(
                  status: _statusDownloading,
                  downloadedBytes: downloaded,
                  totalBytes: math.max(totalBytes, downloaded),
                  localPath: null,
                  error: null,
                );
                lastEmit = now;
              }
            }

            await sink.flush();
          } finally {
            await sink.close();
          }

          if (await target.exists()) {
            await target.delete();
          }
          await partial.rename(target.path);

          final actualSize = await target.length();
          _states[entry.storageKey] = _FallbackDownloadState(
            status: _statusDownloaded,
            downloadedBytes: actualSize,
            totalBytes: math.max(totalBytes, actualSize),
            localPath: target.path,
            error: null,
          );
        } catch (e) {
          _states[entry.storageKey] = _FallbackDownloadState(
            status: _statusFailed,
            downloadedBytes: 0,
            totalBytes: totalBytes,
            localPath: null,
            error: e.toString(),
          );
        } finally {
          _requests.remove(entry.storageKey);
        }
      }),
    );
  }

  Future<_FallbackDownloadState> _statusFor(ModelCatalogEntry entry) async {
    final inMemory = _states[entry.storageKey];
    if (inMemory != null) {
      return inMemory;
    }

    final preloaded = await _preloadedStateFor(entry);
    if (preloaded != null) {
      _states[entry.storageKey] = preloaded;
      return preloaded;
    }

    final target = await _fileFor(entry);
    if (await target.exists()) {
      final size = await target.length();
      final downloaded = _FallbackDownloadState(
        status: _statusDownloaded,
        downloadedBytes: size,
        totalBytes: size,
        localPath: target.path,
        error: null,
      );
      _states[entry.storageKey] = downloaded;
      return downloaded;
    }

    final notDownloaded = const _FallbackDownloadState(
      status: _statusNotDownloaded,
      downloadedBytes: 0,
      totalBytes: 0,
    );
    _states[entry.storageKey] = notDownloaded;
    return notDownloaded;
  }

  Future<_FallbackDownloadState?> _preloadedStateFor(
    ModelCatalogEntry entry,
  ) async {
    final directPath = _preloadedModelPath.trim();
    if (directPath.isNotEmpty) {
      final directFile = File(directPath);
      if (await directFile.exists()) {
        final size = await directFile.length();
        return _FallbackDownloadState(
          status: _statusDownloaded,
          downloadedBytes: size,
          totalBytes: size,
          localPath: directFile.path,
          error: null,
        );
      }
    }

    final cacheDir = _preloadedModelDir.trim();
    if (cacheDir.isNotEmpty) {
      final fromCacheDir = File('$cacheDir/${entry.modelFile}');
      if (await fromCacheDir.exists()) {
        final size = await fromCacheDir.length();
        return _FallbackDownloadState(
          status: _statusDownloaded,
          downloadedBytes: size,
          totalBytes: size,
          localPath: fromCacheDir.path,
          error: null,
        );
      }
    }

    return null;
  }

  Future<File> _fileFor(ModelCatalogEntry entry) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/gemma_models/${entry.storageKey}');
    await dir.create(recursive: true);
    return File('${dir.path}/${entry.modelFile}');
  }
}

const _statusNotDownloaded = 'not_downloaded';
const _statusDownloading = 'downloading';
const _statusDownloaded = 'downloaded';
const _statusFailed = 'failed';

class _FallbackDownloadState {
  const _FallbackDownloadState({
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.localPath,
    this.error,
  });

  final String status;
  final int downloadedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;
}
