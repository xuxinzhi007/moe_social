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
import '../../services/community_service.dart';
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

  final List<File> selectedImages = [];
  final List<String> selectedImageUrls = [];
  List<TopicTag> selectedTopicTags = [];
  HandDrawCardData? handDrawCard;
  String? selectedMoodTag;

  String? userName;
  String? userAvatar;
  String? authorUserId;

  /// 发到群组时：null=校验中，true=已加入，false=未加入
  bool? canPostToGroup;
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
    if (isGroupPost) {
      await loadGroupPostPermission();
    }
  }

  Future<void> loadUserInfo() async {
    final userId = AuthService.currentUser;
    if (userId == null) return;
    try {
      final user = await UserService.getUserInfo(userId);
      if (_disposed) return;
      authorUserId = userId;
      userName = user.username;
      userAvatar = user.avatar.isNotEmpty ? user.avatar : null;
      _notify();
    } catch (e) {
      debugPrint('加载用户信息失败: $e');
    }
  }

  Future<void> loadGroupPostPermission() async {
    final gid = groupId?.trim();
    if (gid == null || gid.isEmpty) return;
    final uid = AuthService.currentUser;
    if (uid == null) {
      canPostToGroup = false;
      _notify();
      return;
    }
    try {
      final group =
          await CommunityService.getCommunityGroup(groupId: gid, userId: uid);
      if (_disposed) return;
      canPostToGroup = group.isJoined;
      _notify();
    } catch (e) {
      debugPrint('校验群成员资格失败: $e');
      if (_disposed) return;
      canPostToGroup = false;
      _notify();
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
    selectedImages.add(file);
    hasUnsavedChanges = true;
    _notify();
  }

  void addCloudImageUrl(String url) {
    selectedImageUrls.add(url);
    hasUnsavedChanges = true;
    _notify();
  }

  void removeLocalImageAt(int index) {
    if (index < 0 || index >= selectedImages.length) return;
    selectedImages.removeAt(index);
    hasUnsavedChanges = true;
    _notify();
  }

  void removeCloudImageUrl(String url) {
    selectedImageUrls.remove(url);
    hasUnsavedChanges = true;
    _notify();
  }

  /// 校验失败返回错误文案；成功返回 null。
  String? validateContent(String caption) {
    final hasLocal = selectedImages.isNotEmpty;
    final hasCloud = selectedImageUrls.isNotEmpty;
    if (caption.trim().isEmpty &&
        handDrawCard == null &&
        !hasLocal &&
        !hasCloud) {
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
        handDrawCard =
            HandDrawCardData.tryParseJsonString(jsonEncode(hand));
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

    if (isGroupPost) {
      if (canPostToGroup == null) {
        await loadGroupPostPermission();
      }
      if (canPostToGroup != true) {
        throw ApiException('请先加入该群组再发帖', 403);
      }
    }

    final imageUrls = <String>[];
    for (final image in selectedImages) {
      try {
        imageUrls.add(await PostService.uploadImage(image));
      } catch (e) {
        throw ApiException(
          MoeErrorCopy.toast(e, scene: MoeErrorScene.feed),
          e is ApiException ? e.code : 500,
        );
      }
    }
    imageUrls.addAll(selectedImageUrls);

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
    final imageUrls = <String>[];
    for (final image in selectedImages) {
      try {
        imageUrls.add(await PostService.uploadImage(image));
      } catch (e) {
        throw ApiException(
          MoeErrorCopy.toast(e, scene: MoeErrorScene.feed),
          e is ApiException ? e.code : 500,
        );
      }
    }
    imageUrls.addAll(selectedImageUrls);

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
      ..addAll(post.images);
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
