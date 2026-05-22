enum LocalModelSource {
  huggingFace('huggingface'),
  serverMirror('server_mirror'),
  ;

  const LocalModelSource(this.value);
  final String value;

  static LocalModelSource fromValue(String raw) {
    for (final item in LocalModelSource.values) {
      if (item.value == raw) return item;
    }
    return LocalModelSource.huggingFace;
  }
}

class LocalLlmModelCatalogItem {
  final String id;
  final String name;
  final String filename;
  final int sizeBytes;
  final String sha256;
  final String description;
  final double parametersB;
  final bool recommended;

  /// 完整下载 URL（HF resolve 或后端 /download）。
  final String downloadPath;
  final LocalModelSource source;
  final String hfRepoId;

  const LocalLlmModelCatalogItem({
    required this.id,
    required this.name,
    required this.filename,
    required this.sizeBytes,
    required this.sha256,
    required this.description,
    required this.parametersB,
    required this.recommended,
    required this.downloadPath,
    this.source = LocalModelSource.huggingFace,
    this.hfRepoId = '',
  });

  bool get isHuggingFace => source == LocalModelSource.huggingFace;

  /// llamadart 可识别的 Hugging Face 源，形如 `hf://owner/repo/file.gguf`。
  String? get hfModelSourceUri {
    if (!isHuggingFace || hfRepoId.isEmpty || filename.isEmpty) {
      return null;
    }
    final repo = hfRepoId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final file = filename.trim().replaceAll(RegExp(r'^/+'), '');
    return 'hf://$repo/$file';
  }

  factory LocalLlmModelCatalogItem.fromJson(Map<String, dynamic> json) {
    return LocalLlmModelCatalogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      sizeBytes: _parseInt(json['size_bytes']),
      sha256: (json['sha256'] ?? '').toString().toLowerCase(),
      description: (json['description'] ?? '').toString(),
      parametersB: _parseDouble(json['parameters_b']),
      recommended: json['recommended'] == true,
      downloadPath: (json['download_path'] ?? '').toString(),
      source: LocalModelSource.fromValue(
        (json['source'] ?? LocalModelSource.serverMirror.value).toString(),
      ),
      hfRepoId: (json['hf_repo_id'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic raw) {
    if (raw is double) return raw;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class InstalledLocalLlmModel {
  final String id;
  final String name;
  final String filename;
  final String filePath;
  final int sizeBytes;
  final String sha256;
  final DateTime installedAt;
  final LocalModelSource source;
  final String hfRepoId;

  const InstalledLocalLlmModel({
    required this.id,
    required this.name,
    required this.filename,
    required this.filePath,
    required this.sizeBytes,
    required this.sha256,
    required this.installedAt,
    this.source = LocalModelSource.huggingFace,
    this.hfRepoId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'filename': filename,
        'file_path': filePath,
        'size_bytes': sizeBytes,
        'sha256': sha256,
        'installed_at': installedAt.toIso8601String(),
        'source': source.value,
        'hf_repo_id': hfRepoId,
      };

  factory InstalledLocalLlmModel.fromJson(Map<String, dynamic> json) {
    return InstalledLocalLlmModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      filename: (json['filename'] ?? '').toString(),
      filePath: (json['file_path'] ?? '').toString(),
      sizeBytes: LocalLlmModelCatalogItem._parseInt(json['size_bytes']),
      sha256: (json['sha256'] ?? '').toString().toLowerCase(),
      installedAt: DateTime.tryParse((json['installed_at'] ?? '').toString()) ??
          DateTime.now(),
      source: LocalModelSource.fromValue(
        (json['source'] ?? LocalModelSource.huggingFace.value).toString(),
      ),
      hfRepoId: (json['hf_repo_id'] ?? '').toString(),
    );
  }
}
