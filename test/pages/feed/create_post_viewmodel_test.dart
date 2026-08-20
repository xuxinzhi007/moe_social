import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/models/topic_tag.dart';
import 'package:moe_social/pages/feed/create_post_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores the complete local draft payload', () async {
    SharedPreferences.setMockInitialValues({});
    final viewModel = CreatePostViewModel();
    addTearDown(viewModel.dispose);
    viewModel
      ..addCloudImageUrl('https://example.com/image.png')
      ..setMoodTag('happy')
      ..setTopicTags([
        TopicTag(
          id: 'daily',
          name: '日常',
          createdAt: DateTime(2026),
          color: Colors.blue,
        ),
      ]);

    await viewModel.saveDraft('今天很开心');

    final restored = CreatePostViewModel();
    addTearDown(restored.dispose);
    final caption = await restored.restoreDraft();

    expect(caption, '今天很开心');
    expect(restored.selectedImageUrls, ['https://example.com/image.png']);
    expect(restored.selectedMoodTag, 'happy');
    expect(restored.selectedTopicTags.single.id, 'daily');
    expect(restored.hasUnsavedChanges, isTrue);
  });

  test('clears a saved draft when no editable content remains', () async {
    SharedPreferences.setMockInitialValues({});
    final viewModel = CreatePostViewModel();
    addTearDown(viewModel.dispose);

    await viewModel.saveDraft('临时内容');
    await viewModel.clearDraft();

    final restored = CreatePostViewModel();
    addTearDown(restored.dispose);
    expect(await restored.restoreDraft(), isNull);
  });
}
