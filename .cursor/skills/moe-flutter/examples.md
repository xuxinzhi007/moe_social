# Moe Flutter · Examples

## Good · Feed

```text
lib/pages/feed/
  home_page.dart              # skeleton + MoeErrorState.onRetry
  home_feed_viewmodel.dart
  create_post_page.dart       # draft restore + MoeErrorCopy on upload
  create_post_viewmodel.dart
  comments_viewmodel.dart     # optimistic insert + rollback
```

## Good · DM loop

```text
ChatPushService.connectionLive  # reconnect banner
DirectChatViewModel.sendText    # optimistic + visible failure
```

## Good · Empty / motion reuse

```dart
// Prefer shared empty (animate default on) over custom panels
MoeEmptyState(
  title: '这里还是空的',
  primaryAction: MoeEmptyStateAction(label: '发布动态', onPressed: openCreate),
);

// List entrance — already in repo
MoeStaggerReveal(index: i, itemKey: id, revealedKeys: keys, child: row);

// Press feedback
MoePressable(onTap: onTap, child: row);
```

## Good · Make silent wins visible

```dart
// Draft restore must toast — otherwise users think nothing changed
MoeToast.info(context, '已恢复未发布的草稿');
```

## Bad · Kitchen sink

```dart
await ApiClient.uploadImage(file);
await http.post(Uri.parse('${ApiClient.baseUrl}/api/llm/...'));
setState(() { /* 40 fields */ });
// ad-hoc empty Column; Color(0xFF7F7FD5) x12
```

## Good · Domain wrap

```dart
// service
static Future<String> uploadImage(File image) => ApiClient.uploadImage(image);
// page
final url = await PostService.uploadImage(image);
```

## Good · Flag

```dart
if (FeatureFlags.showGameFeatures) ...[
  TextButton(onPressed: onStory, child: Text('互动故事')),
]
```

## God-page extraction order

1. IO + list state → ViewModel  
2. Tri-state → moe_*  
3. Extract one display widget  
4. Stop unless asked to continue  
