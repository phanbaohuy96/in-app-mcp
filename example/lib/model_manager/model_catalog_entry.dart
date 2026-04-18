class ModelCatalogEntry {
  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.modelId,
    required this.modelFile,
    required this.sizeInBytes,
    required this.description,
    required this.recommended,
    this.downloadUrl,
    this.checksumSha256,
  });

  final String id;
  final String name;
  final String modelId;
  final String modelFile;
  final int sizeInBytes;
  final String description;
  final bool recommended;
  final String? downloadUrl;
  final String? checksumSha256;

  String get storageKey => id;

  factory ModelCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ModelCatalogEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      modelId: (json['modelId'] ?? '').toString(),
      modelFile: (json['modelFile'] ?? '').toString(),
      sizeInBytes: (json['sizeInBytes'] as num?)?.toInt() ?? 0,
      description: (json['description'] ?? '').toString(),
      recommended: json['recommended'] == true,
      downloadUrl: (json['downloadUrl'] as String?)?.trim(),
      checksumSha256: (json['checksumSha256'] as String?)?.trim(),
    );
  }
}
