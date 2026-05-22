import '../models/local_llm_model_catalog_item.dart';

/// 内置可下载模型清单（从 Hugging Face 等模型站直链到手机，不依赖后端托管文件）。
class HfLocalModelCatalog {
  HfLocalModelCatalog._();

  /// Hugging Face 文件直链：/resolve/main/{filename}
  static String huggingFaceResolveUrl({
    required String repoId,
    required String filename,
  }) {
    final repo = repoId.trim().replaceAll(RegExp(r'^/+|/+$'), '');
    final file = filename.trim().replaceAll(RegExp(r'^/+'), '');
    return 'https://huggingface.co/$repo/resolve/main/$file';
  }

  /// 默认推荐：中文友好、体积适中。
  static const List<LocalLlmModelCatalogItem> presets = [
    LocalLlmModelCatalogItem(
      id: 'qwen2.5-0.5b-instruct-q4',
      name: 'Qwen2.5 0.5B 极速',
      filename: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      sizeBytes: 397000000,
      sha256: '',
      description: '约 400MB，适合弱机与快速回复；来源 Hugging Face 官方 GGUF。',
      parametersB: 0.5,
      recommended: true,
      downloadPath: '',
      source: LocalModelSource.huggingFace,
      hfRepoId: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
    ),
    LocalLlmModelCatalogItem(
      id: 'qwen2.5-1.5b-instruct-q4',
      name: 'Qwen2.5 1.5B 推荐',
      filename: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      sizeBytes: 1100000000,
      sha256: '',
      description: '约 1.1GB，中文效果更好；Wi‑Fi 下下载，一次安装长期离线。',
      parametersB: 1.5,
      recommended: false,
      downloadPath: '',
      source: LocalModelSource.huggingFace,
      hfRepoId: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
    ),
    LocalLlmModelCatalogItem(
      id: 'smollm2-360m-instruct-q8',
      name: 'SmolLM2 360M',
      filename: 'SmolLM2-360M-Instruct-Q8_0.gguf',
      sizeBytes: 380000000,
      sha256: '',
      description: '超轻量英文/通用；适合体验本地推理流程。',
      parametersB: 0.36,
      recommended: false,
      downloadPath: '',
      source: LocalModelSource.huggingFace,
      hfRepoId: 'HuggingFaceTB/SmolLM2-360M-Instruct-GGUF',
    ),
  ];

  static List<LocalLlmModelCatalogItem> withResolvedUrls() {
    return presets
        .map(
          (item) => LocalLlmModelCatalogItem(
            id: item.id,
            name: item.name,
            filename: item.filename,
            sizeBytes: item.sizeBytes,
            sha256: item.sha256,
            description: item.description,
            parametersB: item.parametersB,
            recommended: item.recommended,
            downloadPath: item.hfRepoId.isEmpty
                ? item.downloadPath
                : huggingFaceResolveUrl(
                    repoId: item.hfRepoId,
                    filename: item.filename,
                  ),
            source: item.source,
            hfRepoId: item.hfRepoId,
          ),
        )
        .toList();
  }
}
