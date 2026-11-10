import 'package:flutter/material.dart';

import '../../services/ai_cloud_config_service.dart';
import '../../services/chat_model_selection.dart';
import '../../services/llm_api_service.dart';
import '../moe_action_row.dart';
import '../moe_toast.dart';
import 'ai_sheet.dart';

/// 陪伴聊天顶栏「切换模型」的共用实现：同一份目录、同一条用户偏好。
abstract final class ChatModelPicker {
  static Future<String?> showSheet({
    required BuildContext context,
    required String currentModel,
    required List<LlmCatalogModel> models,
  }) {
    return AiSheet.show<String>(
      context: context,
      title: '切换模型',
      subtitle: '在聊天里换。基座提示词只能看，自己的模型可以改。',
      initialChildSize: 0.62,
      minChildSize: 0.32,
      maxChildSize: 0.9,
      child: ChatModelPickerList(
        models: models,
        currentModel: currentModel,
        onSelect: (name) => Navigator.of(context).pop(name),
      ),
    );
  }

  /// 拉目录、弹出与陪伴聊天相同的切换页，并把选择写入 `builtin_chat_model`。
  static Future<String?> pickAndSave({
    required BuildContext context,
    required String currentModel,
  }) async {
    List<LlmCatalogModel> models;
    try {
      models = await LlmApiService.fetchCatalog();
    } catch (error) {
      if (context.mounted) {
        MoeToast.error(context, '模型列表读取失败：$error');
      }
      return null;
    }
    models = models.where((item) => item.name.isNotEmpty).toList();
    if (!context.mounted) return null;
    if (models.isEmpty) {
      MoeToast.error(context, '小主机上没有可读到的模型');
      return null;
    }
    final selected = await showSheet(
      context: context,
      currentModel: currentModel,
      models: models,
    );
    if (selected == null || selected == currentModel || !context.mounted) {
      return null;
    }
    try {
      final cloud = AiCloudConfigService();
      final snapshot = await cloud.fetch();
      await cloud.savePreferences(
        ChatModelSelection.withBuiltinModel(snapshot?.preferences, selected),
      );
    } catch (error) {
      if (context.mounted) {
        MoeToast.error(context, '模型没有切换成功：$error');
      }
      return null;
    }
    return selected;
  }
}

class ChatModelPickerList extends StatelessWidget {
  const ChatModelPickerList({
    super.key,
    required this.models,
    required this.currentModel,
    required this.onSelect,
  });

  final List<LlmCatalogModel> models;
  final String currentModel;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final bases = ChatModelSelection.baseModels(models);
    final mine = ChatModelSelection.derivedModels(models);
    return Column(
      children: [
        if (bases.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('小主机上的模型'),
            ),
          ),
        for (final model in bases)
          MoeActionRow(
            icon: Icons.memory_rounded,
            title: model.name,
            selected: model.name == currentModel,
            subtitle: Text(
              [
                if (model.contextLength > 0) '上下文 ${model.contextLength}',
                model.thinking ? '可以思考' : '没有思考能力',
                '提示词只能看',
              ].join(' · '),
            ),
            onTap: () => onSelect(model.name),
          ),
        if (mine.isNotEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('我的模型'),
            ),
          ),
        for (final model in mine)
          MoeActionRow(
            icon: Icons.tune_rounded,
            title: model.name,
            selected: model.name == currentModel,
            subtitle: Text(
              [
                if (model.contextLength > 0) '上下文 ${model.contextLength}',
                '可以改提示词',
              ].join(' · '),
            ),
            onTap: () => onSelect(model.name),
          ),
      ],
    );
  }
}
