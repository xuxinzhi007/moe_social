import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth_service.dart';
import '../../models/achievement_unlock.dart';
import '../../models/hand_draw_card.dart';
import '../../models/post.dart';
import '../../models/topic_tag.dart';
import '../../services/api_client.dart' show ApiException;
import '../../services/companion_service.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../utils/hand_draw_raster.dart';
import '../../utils/moe_error_copy.dart';

/// 发帖/编辑发布结果（页面负责导航与 Toast）。
class CreatePostPublishResult {
  const CreatePostPublishResult({
    required this.post,
    this.newAchievements = const [],
    this.successMessage = '帖子发布成功！(≧∇≦)/',
    this.softWarning,
  });

  final Post post;
  final List<AchievementUnlock> newAchievements;
  final String successMessage;

  /// 非阻断提示（如手绘缩略图上传失败仍发布成功）。
  final String? softWarning;
}

/// 发帖页里的一张图：选中后立刻上传，发布时只提交已经拿到的地址。
class ComposerImage {
  ComposerImage.file(this.file)
      : remoteUrl = null,
        uploading = true,
        error = null;

  ComposerImage.remote(String url)
      : file = null,
        remoteUrl = url,
        uploading = false,
        error = null;

  final File? file;
  String? remoteUrl;
  bool uploading;
  String? error;

  bool get isReady => remoteUrl != null && remoteUrl!.isNotEmpty;
}

/// 发帖页状态：作者信息、群权限、选图/话题/心情、发布/编辑 IO、本地草稿。
class CreatePostViewModel extends ChangeNotifier {
  CreatePostViewModel({
    this.initialPost,
    this.groupId,
    this.communityIdentity,
  });

  static const String _draftPrefsKey = 'create_post_draft_v1';

  final Post? initialPost;
  final String? groupId;
  final CompanionCommunityIdentityData? communityIdentity;

  final List<ComposerImage> composerImages = [];
  final List<String> selectedImageUrls = [];
  final Map<ComposerImage, Future<void>> _uploads = {};
  List<TopicTag> selectedTopicTags = [];
  HandDrawCardData? handDrawCard;
  String? selectedMoodTag;

  String? userName;
  String? userAvatar;
  String? authorUserId;

  bool hasUnsavedChanges = false;
  bool _disposed = false;

  bool get isEditMode => initialPost != null;
  bool get isGroupPost =>
      !isEditMode && groupId != null && groupId!.trim().isNotEmpty;

  Future<void> bootstrap() async {
    final identity = communityIdentity;
    if (identity != null && identity.isValid) {
      authorUserId = identity.userId;
      userName = identity.userName.isNotEmpty ? identity.userName : 'AI 伙伴';
      userAvatar = identity.userAvatar.isNotEmpty ? identity.userAvatar : null;
      _notify();
    } else {
      await loadUserInfo();
    }
  }

  Future<void> loadUserInfo() async {
    final uid = AuthService.currentUser;
    if (uid == null) return;
    try {
      final user = await UserService.getUserInfo(uid);
      if (_disposed) return;
      authorUserId = uid;
      userName = user.username;
      userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      _notify();
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  void markDirty() {
    if (hasUnsavedChanges) return;
    hasUnsavedChanges = true;
    _notify();
  }

  void setHandDraw(HandDrawCardData? data) {
    handDrawCard = data;
    hasUnsavedChanges = true;
    _notify();
  }

  void setMoodTag(String? tag) {
    selectedMoodTag = tag;
    hasUnsavedChanges = true;
    _notify();
  }

  void setTopicTags(List<TopicTag> tags) {
    selectedTopicTags = tags;
    hasUnsavedChanges = true;
    _notify();
  }

  void addLocalImage(File file) {
    final slot = ComposerImage.file(file);
    composerImages.add(slot);
    hasUnsavedChanges = true;
    _notify();
    unawaited(_uploadSlot(slot));
  }

  void addCloudImageUrl(String url) {
    if (url.isEmpty) return;
    composerImages.add(ComposerImage.remote(url));
    _syncUploadedUrls();
    hasUnsavedChanges = true;
    _notify();
  }

  void removeComposerImage(ComposerImage slot) {
    composerImages.remove(slot);
    _uploads.remove(slot);
    _syncUploadedUrls();
    hasUnsavedChanges = true;
    _notify();
  }

  void retryComposerImage(ComposerImage slot) {
    if (!composerImages.contains(slot) || slot.file == null || slot.isReady) {
      return;
    }
    _uploads.remove(slot);
    unawaited(_uploadSlot(slot));
  }

  /// 校验失败返回错误文案；成功返回 null。
  String? validateContent(String caption) {
    if (caption.trim().isEmpty &&
        handDrawCard == null &&
        composerImages.isEmpty) {
      return '写点文字、选几张图，或画一张手绘卡片再发布吧';
    }
    return null;
  }

  /// 持久化草稿（正文 + 云图 URL + 话题 + 心情）。本地 File 路径不跨会话保证可用，故不存。
  Future<void> saveDraft(String caption) async {
    if (isEditMode || isGroupPost) return;
    final trimmed = caption.trim();
    final empty = trimmed.isEmpty &&
        selectedImageUrls.isEmpty &&
        selectedTopicTags.isEmpty &&
        (selectedMoodTag == null || selectedMoodTag!.isEmpty) &&
        handDrawCard == null;
    if (empty) {
      await clearDraft();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'caption': caption,
        'imageUrls': selectedImageUrls,
        'moodTag': selectedMoodTag ?? '',
        'topics': selectedTopicTags.map((t) => t.toJson()).toList(),
        if (handDrawCard != null) 'handDraw': handDrawCard!.toJson(),
      };
      await prefs.setString(_draftPrefsKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('保存发帖草稿失败: $e');
    }
  }

  /// 恢复草稿；返回正文（可能为空串）。编辑模式跳过。
  Future<String?> restoreDraft() async {
    if (isEditMode || isGroupPost) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final data = Map<String, dynamic>.from(map);
      final caption = (data['caption'] as String?) ?? '';
      final urls = data['imageUrls'];
      if (urls is List) {
        selectedImageUrls
          ..clear()
          ..addAll(urls.map((e) => e.toString()).where((e) => e.isNotEmpty));
        composerImages
          ..clear()
          ..addAll(selectedImageUrls.map(ComposerImage.remote));
      }
      final mood = (data['moodTag'] as String?) ?? '';
      selectedMoodTag = mood.isEmpty ? null : mood;
      final topics = data['topics'];
      if (topics is List) {
        selectedTopicTags = topics
            .whereType<Map>()
            .map((e) => TopicTag.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      final hand = data['handDraw'];
      if (hand is Map) {
        handDrawCard = HandDrawCardData.tryParseJsonString(jsonEncode(hand));
      }
      if (caption.isNotEmpty ||
          selectedImageUrls.isNotEmpty ||
          selectedTopicTags.isNotEmpty ||
          selectedMoodTag != null ||
          handDrawCard != null) {
        hasUnsavedChanges = true;
      }
      _notify();
      return caption;
    } catch (e) {
      debugPrint('恢复发帖草稿失败: $e');
      return null;
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftPrefsKey);
    } catch (e) {
      debugPrint('清除发帖草稿失败: $e');
    }
  }

  Future<CreatePostPublishResult> publish(String caption) async {
    if (isEditMode) {
      final post = await _saveEdit(caption);
      hasUnsavedChanges = false;
      await clearDraft();
      return CreatePostPublishResult(
        post: post,
        successMessage: '动态已更新 ✨',
      );
    }

    final imageUrls = await _collectImageUrls();

    final userId = authorUserId ?? AuthService.currentUser;
    if (userId == null || userId.isEmpty) {
      throw ApiException('请先登录', 401);
    }

    var handJson = '';
    var thumbUrl = '';
    String? softWarning;
    final card = handDrawCard;
    if (card != null) {
      handJson = jsonEncode(card.toJson());
      try {
        final png = await handDrawCardToPngBytes(card);
        if (png != null && png.isNotEmpty) {
          thumbUrl = await PostService.uploadImageBytes(
            png,
            filename: 'hand_draw_thumb.png',
          );
        }
      } catch (e) {
        softWarning = '手绘缩略图上传失败，已用原文继续发布';
        debugPrint('手绘缩略图上传失败，继续发布: $e');
      }
    }

    final newPost = Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userName: userName ?? '用户',
      userAvatar: userAvatar ?? '',
      content: caption,
      images: imageUrls,
      likes: 0,
      comments: 0,
      isLiked: false,
      createdAt: DateTime.now(),
      topicTags: selectedTopicTags,
      handDrawCardJson: handJson,
      handDrawThumbUrl: thumbUrl,
      moodTag: selectedMoodTag ?? '',
    );

    try {
      final created = await PostService.createPostWithUnlocks(
        newPost,
        groupId: groupId,
      );
      final apiPost = created.post;
      final merged = apiPost.copyWith(
        handDrawCardJson: apiPost.handDrawCardJson.isNotEmpty
            ? apiPost.handDrawCardJson
            : handJson,
        handDrawThumbUrl: apiPost.handDrawThumbUrl.isNotEmpty
            ? apiPost.handDrawThumbUrl
            : thumbUrl,
      );
      hasUnsavedChanges = false;
      await clearDraft();
      final msg = groupId != null && groupId!.isNotEmpty
          ? '已发布并同步到群组 ~(≧∇≦)/~'
          : '帖子发布成功！(≧∇≦)/';
      return CreatePostPublishResult(
        post: merged,
        newAchievements: created.newAchievements,
        successMessage: msg,
        softWarning: softWarning,
      );
    } catch (e) {
      throw ApiException(
        MoeErrorCopy.toast(e, scene: MoeErrorScene.feed),
        e is ApiException ? e.code : 500,
      );
    }
  }

  Future<Post> _saveEdit(String caption) async {
    final init = initialPost!;
    final imageUrls = await _collectImageUrls();

    String? handJson;
    String? thumbUrl;
    final card = handDrawCard;
    if (card != null) {
      handJson = jsonEncode(card.toJson());
      if (handJson != init.handDrawCardJson) {
        try {
          final png = await handDrawCardToPngBytes(card);
          if (png != null && png.isNotEmpty) {
            thumbUrl = await PostService.uploadImageBytes(
              png,
              filename: 'hand_draw_thumb.png',
            );
          }
        } catch (e) {
          debugPrint('编辑动态时手绘缩略图上传失败，继续保存: $e');
          thumbUrl = init.handDrawThumbUrl;
        }
      } else {
        thumbUrl = init.handDrawThumbUrl;
      }
    }

    return PostService.updatePost(
      init.id,
      content: caption,
      images: imageUrls,
      topicTags: selectedTopicTags
          .map((t) => {'name': t.name, 'color': t.color})
          .toList(),
      handDrawCard: handJson,
      handDrawThumbUrl: thumbUrl,
    );
  }

  void seedFromInitialPost(Post post) {
    selectedImageUrls
      ..clear()
      ..addAll(post.images.where((e) => e.isNotEmpty));
    composerImages
      ..clear()
      ..addAll(selectedImageUrls.map(ComposerImage.remote));
    selectedTopicTags = List<TopicTag>.from(post.topicTags);
    selectedMoodTag = post.moodTag.isNotEmpty ? post.moodTag : null;
    if (post.handDrawCardJson.isNotEmpty) {
      handDrawCard = HandDrawCardData.tryParseJsonString(post.handDrawCardJson);
    }
    authorUserId = post.userId;
    userName = post.userName;
    userAvatar = post.userAvatar.isNotEmpty ? post.userAvatar : null;
    hasUnsavedChanges = false;
    _notify();
  }

  Future<List<String>> _collectImageUrls() async {
    await _flushImageUploads();
    final urls = <String>[];
    for (final slot in composerImages) {
      final url = slot.remoteUrl;
      if (url == null || url.isEmpty) {
        throw ApiException(slot.error ?? '图片还没上传成功，请重试', 500);
      }
      urls.add(url);
    }
    return urls;
  }

  Future<void> _flushImageUploads() async {
    final pending = <Future<void>>[];
    for (final slot in List<ComposerImage>.from(composerImages)) {
      if (slot.isReady || slot.file == null) continue;
      pending.add(_uploadSlot(slot));
    }
    if (pending.isNotEmpty) {
      await Future.wait(pending);
    }
  }

  Future<void> _uploadSlot(ComposerImage slot) {
    final inflight = _uploads[slot];
    if (inflight != null) return inflight;
    final file = slot.file;
    if (file == null || slot.isReady) return Future<void>.value();
    slot.uploading = true;
    slot.error = null;
    _notify();
    final future = _runUpload(slot, file);
    _uploads[slot] = future;
    return future;
  }

  Future<void> _runUpload(ComposerImage slot, File file) async {
    try {
      final url = await PostService.uploadImage(file);
      if (_disposed || !composerImages.contains(slot)) return;
      slot.remoteUrl = url;
      slot.uploading = false;
      slot.error = null;
      _syncUploadedUrls();
    } catch (e) {
      if (_disposed || !composerImages.contains(slot)) return;
      slot.uploading = false;
      slot.error = MoeErrorCopy.toast(e, scene: MoeErrorScene.feed);
    } finally {
      _uploads.remove(slot);
      if (!_disposed && composerImages.contains(slot)) _notify();
    }
  }

  void _syncUploadedUrls() {
    selectedImageUrls
      ..clear()
      ..addAll(
        composerImages
            .map((slot) => slot.remoteUrl)
            .whereType<String>()
            .where((url) => url.isNotEmpty),
      );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
