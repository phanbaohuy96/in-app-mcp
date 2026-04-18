enum ModelInstallPhase { notDownloaded, downloading, downloaded, failed }

class ModelInstallState {
  const ModelInstallState({
    required this.phase,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localPath,
    this.error,
  });

  final ModelInstallPhase phase;
  final int downloadedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelInstallState &&
            other.phase == phase &&
            other.downloadedBytes == downloadedBytes &&
            other.totalBytes == totalBytes &&
            other.localPath == localPath &&
            other.error == error);
  }

  @override
  int get hashCode =>
      Object.hash(phase, downloadedBytes, totalBytes, localPath, error);

  bool get isDownloading => phase == ModelInstallPhase.downloading;

  bool get isDownloaded => phase == ModelInstallPhase.downloaded;

  double get progress {
    if (totalBytes <= 0) {
      return 0;
    }
    return (downloadedBytes / totalBytes).clamp(0, 1);
  }

  factory ModelInstallState.fromMap(Map<String, dynamic> map) {
    final status = (map['status'] ?? 'not_downloaded').toString();
    final phase = switch (status) {
      'downloading' => ModelInstallPhase.downloading,
      'downloaded' => ModelInstallPhase.downloaded,
      'failed' => ModelInstallPhase.failed,
      _ => ModelInstallPhase.notDownloaded,
    };
    return ModelInstallState(
      phase: phase,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      localPath: map['localPath'] as String?,
      error: map['error'] as String?,
    );
  }
}
