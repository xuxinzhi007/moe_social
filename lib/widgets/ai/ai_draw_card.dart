// Hallmark · layout: media-card · tone: kawaii-soft · scroll: none
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import '../../services/comfy_draw_preferences.dart';
import '../../services/gallery_service.dart';
import '../../theme/moe_tokens.dart';
import '../../utils/media_url.dart';
import '../moe_loading.dart';
import '../moe_toast.dart';
import '../motion/moe_pressable.dart';
import '../motion/moe_shimmer.dart';
import '../post_image_viewer.dart';

/// AI 聊天内嵌 ComfyUI 绘图卡片（A + B 融合方案）：
///
/// - **流式构思中**（`isIncomplete == true`）：展示「正在构思画面提示词…」动态胶囊；
/// - **当场闭合**（刚从 `isIncomplete: true` 过渡为 `false`，或缓存已命中）：
///   - 若本地缓存已有该 Prompt 生成的 URL，0ms 直接展示图片；
///   - 若为当场新生成的 `<draw>` 指令，**自动触发**本地 ComfyUI 生图（方案 A）；
///   - 若为重进页面加载的旧历史且本地无缓存，显示「点击通过 ComfyUI 绘制」（方案 B，保护 8GB 显存不重刷）；
/// - **底部操作栏**：一键「复制提示词」、「换一张（随机 Seed 重绘）」、点击大图全屏预览。
class AiDrawCard extends StatefulWidget {
  const AiDrawCard({
    super.key,
    required this.prompt,
    this.isIncomplete = false,
    this.autoGenerateOnMount = false,
  });

  final String prompt;
  final bool isIncomplete;

  /// 当该气泡处于当次实时回复流中挂载时为 true，确保即使 `<draw>...</draw>` 在单个 chunk 内闭合也能自动触发。
  final bool autoGenerateOnMount;

  @override
  State<AiDrawCard> createState() => _AiDrawCardState();
}

class _AiDrawCardState extends State<AiDrawCard> {
  static final Map<String, String> _memoryUrlCache = <String, String>{};
  static final Map<String, Future<String>> _inFlightByKey =
      <String, Future<String>>{};

  String? _imageUrl;
  bool _generating = false;
  String? _error;
  bool _promptExpanded = false;
  bool _sawIncomplete = false;
  bool _checkedCache = false;

  /// 当前图片是由哪种画风生成的（`'anime'` 或 `'realistic'`）。
  String? _renderedStyle;

  String get _cleanPrompt => widget.prompt.trim();

  String get _activeStyle => ComfyDrawPreferences.currentStyle;

  String get _cacheKey => _cacheKeyForStyle(_activeStyle);

  String _cacheKeyForStyle(String style) {
    final normalized =
        _cleanPrompt.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    var hash = 5381;
    for (final code in normalized.codeUnits) {
      hash = ((hash << 5) + hash) ^ code;
    }
    final hex = (hash & 0x7fffffff).toRadixString(16);
    return 'comfy_draw_v4_${style}_${normalized.length}_$hex';
  }

  @override
  void initState() {
    super.initState();
    _sawIncomplete = widget.isIncomplete || widget.autoGenerateOnMount;
    ComfyDrawPreferences.styleNotifier.addListener(_onGlobalStyleChanged);
    if (!widget.isIncomplete && _cleanPrompt.isNotEmpty) {
      unawaited(
        _bootstrapFinishedPrompt(
          autoGenerateIfUncached: widget.autoGenerateOnMount,
        ),
      );
    }
  }

  @override
  void dispose() {
    ComfyDrawPreferences.styleNotifier.removeListener(_onGlobalStyleChanged);
    super.dispose();
  }

  void _onGlobalStyleChanged() {
    if (!mounted) return;
    final targetStyle = _activeStyle;
    final mem = _memoryUrlCache[_cacheKeyForStyle(targetStyle)];
    setState(() {
      if (mem != null && mem.isNotEmpty) {
        _imageUrl = mem;
        _renderedStyle = targetStyle;
      }
    });
  }

  @override
  void didUpdateWidget(covariant AiDrawCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isIncomplete || widget.autoGenerateOnMount) {
      _sawIncomplete = true;
    }
    if (widget.isIncomplete) {
      return;
    }
    if ((oldWidget.isIncomplete && !widget.isIncomplete) ||
        (oldWidget.prompt != widget.prompt && _cleanPrompt.isNotEmpty)) {
      unawaited(
        _bootstrapFinishedPrompt(autoGenerateIfUncached: _sawIncomplete),
      );
    }
  }

  Future<void> _bootstrapFinishedPrompt({
    required bool autoGenerateIfUncached,
  }) async {
    final style = _activeStyle;
    final key = _cacheKeyForStyle(style);
    final mem = _memoryUrlCache[key];
    if (mem != null && mem.isNotEmpty) {
      if (mounted) {
        setState(() {
          _imageUrl = mem;
          _renderedStyle = style;
          _checkedCache = true;
        });
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final disk = prefs.getString(key)?.trim();
      if (disk != null && disk.isNotEmpty) {
        _memoryUrlCache[key] = disk;
        if (mounted) {
          setState(() {
            _imageUrl = disk;
            _renderedStyle = style;
            _checkedCache = true;
          });
        }
        return;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _checkedCache = true);

    final inflight = _inFlightByKey[key];
    if (inflight != null) {
      await _attachInFlight(key, inflight);
      return;
    }

    if (autoGenerateIfUncached) {
      await _generateImage();
    }
  }

  Future<void> _attachInFlight(String key, Future<String> flight) async {
    if (!mounted) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final url = await flight;
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _generating = false;
      });
    }
  }

  Future<void> _generateImage({bool forceNewSeed = false}) async {
    if (_cleanPrompt.isEmpty || _generating) return;
    final style = _activeStyle;
    final key = _cacheKeyForStyle(style);
    final isAnime = style == ComfyDrawPreferences.styleAnime;

    if (!forceNewSeed && _inFlightByKey.containsKey(key)) {
      await _attachInFlight(key, _inFlightByKey[key]!);
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    final seed = forceNewSeed
        ? (DateTime.now().millisecondsSinceEpoch ^
                math.Random().nextInt(1 << 20)) &
            0x7fffffff
        : null;

    // 显式透传本机 ComfyUI 对应的动漫/写实底模与参数，保证即使后端未重启也能立即切到动漫模型。
    final effectivePrompt = isAnime &&
            !_cleanPrompt.toLowerCase().contains('anime')
        ? 'masterpiece, best quality, anime style, 2d illustration, $_cleanPrompt'
        : _cleanPrompt;
    final checkpoint = isAnime
        ? 'meinamix_v12Final.safetensors'
        : 'Realistic_Vision_V5.1_fp16-no-ema.safetensors';
    final negative = isAnime
        ? 'realistic, photorealistic, 3d, bad anatomy, bad hands, extra fingers, missing fingers, worst quality, low quality, blurry, watermark, text, deformed, ugly'
        : null;

    final future = GalleryService.generateComfyImage(
      prompt: effectivePrompt,
      style: style,
      checkpoint: checkpoint,
      negative: negative,
      cfg: isAnime ? 6.5 : 5.0,
      seed: seed,
    );
    _inFlightByKey[key] = future;

    try {
      final url = await future;
      _memoryUrlCache[key] = url;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, url);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _renderedStyle = style;
        _generating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(e);
        _generating = false;
      });
    } finally {
      if (identical(_inFlightByKey[key], future)) {
        _inFlightByKey.remove(key);
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) return e.message;
    final text = e.toString().replaceFirst('Exception: ', '').trim();
    if (text.isEmpty) return '本机 ComfyUI 未响应，请确认已启动 8188 端口';
    return text;
  }

  Future<void> _copyPrompt() async {
    if (_cleanPrompt.isEmpty) return;
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: _cleanPrompt));
    if (!mounted) return;
    MoeToast.success(context, '绘画提示词已复制');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isIncomplete) {
      return _buildDraftingBanner();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: MoeTokens.surface1,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: MoeTokens.surfaceBorder),
        boxShadow: MoeTokens.shadowSm(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_imageUrl != null && _imageUrl!.isNotEmpty && !_generating)
            _buildRenderedImage(_imageUrl!)
          else if (_generating)
            _buildGeneratingCanvas()
          else if (_error != null)
            _buildErrorCanvas(_error!)
          else if (_checkedCache)
            _buildManualStartCanvas(),
          _buildBottomBar(),
          if (_promptExpanded && _cleanPrompt.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: const BoxDecoration(
                color: MoeTokens.pageBackground,
                border: Border(
                  top: BorderSide(color: MoeTokens.surfaceBorder),
                ),
              ),
              child: SelectableText(
                _cleanPrompt,
                style: const TextStyle(
                  fontSize: MoeTokens.textXs,
                  fontFamily: 'monospace',
                  color: MoeTokens.inkMuted,
                  height: 1.45,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraftingBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MoeTokens.softLavenderBg,
        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
        border: Border.all(color: MoeTokens.surfaceBorder),
      ),
      child: Row(
        children: [
          const MoeSmallLoading(size: 16, color: MoeTokens.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _cleanPrompt.isEmpty ? '正在构思画面提示词…' : '正在编写提示词：$_cleanPrompt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                fontWeight: FontWeight.w700,
                color: MoeTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingCanvas() {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MoeShimmer(
            child: Container(color: MoeTokens.softChipBg),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: MoeTokens.surface1.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                border: Border.all(color: MoeTokens.surfaceBorder),
                boxShadow: MoeTokens.shadowSm(),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MoeSmallLoading(size: 16, color: MoeTokens.primary),
                  SizedBox(width: 8),
                  Text(
                    '正在通过本地 ComfyUI 绘制…',
                    style: TextStyle(
                      fontSize: MoeTokens.textSm,
                      fontWeight: FontWeight.w700,
                      color: MoeTokens.titleText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualStartCanvas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: MoeTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.palette_outlined,
              color: MoeTokens.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI 绘画提示词已就绪',
                  style: TextStyle(
                    fontSize: MoeTokens.textBase,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _cleanPrompt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: MoeTokens.textXs,
                    color: MoeTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          MoePressable(
            onTap: () => unawaited(_generateImage()),
            borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: MoeTokens.gradientPrimary,
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    '生成图片',
                    style: TextStyle(
                      fontSize: MoeTokens.textXs,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCanvas(String message) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MoeTokens.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.error_outline_rounded,
              color: MoeTokens.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: MoeTokens.textSm,
                color: MoeTokens.inkMuted,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => unawaited(_generateImage()),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('重试'),
            style: TextButton.styleFrom(
              foregroundColor: MoeTokens.primary,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  void _onDrawFailed() {
    final key = _cacheKey;
    _memoryUrlCache.remove(key);
    unawaited(
      SharedPreferences.getInstance().then((prefs) => prefs.remove(key)),
    );
  }

  Widget _buildRenderedImage(String rawUrl) {
    final resolved = resolveMediaUrl(rawUrl);
    final heroTag = 'comfy_draw_${_cacheKey}_$resolved';
    final headers = ApiClient.tunnelBypassHeadersForUrl(resolved);

    return GestureDetector(
      onTap: () {
        PostImageViewer.show(
          context,
          imageUrls: [rawUrl],
          postId: _cacheKey,
          heroTagPrefix: 'comfy_',
        );
      },
      child: Hero(
        tag: heroTag,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 180,
            maxHeight: 320,
          ),
          child: Image.network(
            resolved,
            headers: headers.isEmpty ? null : headers,
            fit: BoxFit.cover,
            width: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                height: 220,
                child: MoeShimmer(
                  child: Container(color: MoeTokens.softChipBg),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint('AiDrawCard image load failed ($resolved): $error');
              _onDrawFailed();
              return SizedBox(
                height: 160,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          color: MoeTokens.hintText,
                          size: 36,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () =>
                              unawaited(_generateImage(forceNewSeed: true)),
                          child: const Text('图片加载失败，点此重新生成'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final styleLabel = ComfyDrawPreferences.currentStyleLabel;
    final styleMismatch =
        hasImage && _renderedStyle != null && _renderedStyle != _activeStyle;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _generating
                    ? null
                    : () async {
                        HapticFeedback.selectionClick();
                        if (!styleMismatch) {
                          await ComfyDrawPreferences.toggleStyle();
                        }
                        if (!mounted) return;
                        setState(() {});
                        unawaited(_generateImage(forceNewSeed: true));
                      },
                borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MoeTokens.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_fix_high_rounded,
                        size: 12,
                        color: MoeTokens.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        styleMismatch ? '转$styleLabel' : styleLabel,
                        style: const TextStyle(
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w800,
                          color: MoeTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _promptExpanded = !_promptExpanded),
                borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: MoeTokens.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _promptExpanded ? '收起' : '提示词',
                        style: const TextStyle(
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 2),
              InkWell(
                onTap: _copyPrompt,
                borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 13,
                        color: MoeTokens.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '复制',
                        style: TextStyle(
                          fontSize: MoeTokens.textXs,
                          fontWeight: FontWeight.w700,
                          color: MoeTokens.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (hasImage && !_generating)
            InkWell(
              onTap: () => unawaited(_generateImage(forceNewSeed: true)),
              borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: MoeTokens.primary,
                    ),
                    SizedBox(width: 3),
                    Text(
                      '重绘',
                      style: TextStyle(
                        fontSize: MoeTokens.textXs,
                        fontWeight: FontWeight.w700,
                        color: MoeTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
