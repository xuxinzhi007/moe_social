import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/ai_managed_models_viewmodel.dart';
import '../../services/llm_api_service.dart';
import '../../theme/moe_tokens.dart';
import '../moe_error_state.dart';
import '../moe_loading.dart';
import 'ai_confirm_sheet.dart';
import 'ai_empty_state.dart';
import 'ai_sheet.dart';
import 'ai_surface_card.dart';
import 'ai_theme.dart';

/// 模型来源中的本人模型管理弹层（包含孤立角色卡的模型）。
class AiManagedModelsSheet extends StatelessWidget {
  const AiManagedModelsSheet({super.key});

  static Future<void> show(BuildContext context) => AiSheet.show<void>(
        context: context,
        title: '本人模型管理',
        subtitle: '仅显示当前账号模型，包含已删除角色卡的模型。删除角色卡不会删除模型。',
        child: ChangeNotifierProvider(
          create: (_) => AiManagedModelsViewModel()..load(),
          child: const AiManagedModelsSheet(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AiManagedModelsViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: vm.busy || vm.accountChanged ? null : vm.load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('刷新列表'),
        ),
        if (vm.busy && vm.models.isNotEmpty) const LinearProgressIndicator(),
        if (vm.error != null)
          MoeErrorState.fromError(vm.error, onRetry: vm.load),
        if (vm.notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceMd),
            child: Text(vm.notice!, style: AiTheme.body),
          ),
        if (vm.models.isEmpty && vm.error == null)
          vm.busy
              ? const Padding(
                  padding: EdgeInsets.all(MoeTokens.spaceLg),
                  child: Center(child: MoeLoading()),
                )
              : const AiEmptyState(
                  title: '暂无本人模型',
                  subtitle: '可在角色卡编辑的高级选项中显式创建。基座需由管理员预先安装。',
                ),
        ...vm.models.map((model) => _modelCard(context, vm, model)),
      ],
    );
  }

  Widget _modelCard(BuildContext context, AiManagedModelsViewModel vm,
          LlmManagedModel model) =>
      AiSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(model.modelName, style: AiTheme.title),
            const SizedBox(height: MoeTokens.spaceSm),
            Text('基座：${model.baseModel}', style: AiTheme.caption),
            Text('角色卡 ID：${model.agentId}', style: AiTheme.caption),
            Text('状态：${model.statusLabel}', style: AiTheme.body),
            if (model.isUnresolved)
              Text(model.outcomeMessage, style: AiTheme.caption),
            Wrap(
              spacing: MoeTokens.spaceSm,
              children: [
                TextButton.icon(
                  onPressed:
                      vm.busy || vm.accountChanged || model.state == 'deleted'
                          ? null
                          : () => vm.reconcile(model),
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('重查'),
                ),
                TextButton.icon(
                  style:
                      TextButton.styleFrom(foregroundColor: MoeTokens.danger),
                  onPressed: vm.busy ||
                          vm.accountChanged ||
                          model.isUnresolved ||
                          model.state == 'deleted'
                      ? null
                      : () async {
                          final ok = await AiConfirmSheet.show(
                            context: context,
                            title: '删除本人模型',
                            message:
                                '确定删除「${model.modelName}」吗？此操作仅删除你的派生模型，不删除角色卡或共享基座。使用此模型的聊天可能需要重新选择模型。',
                            confirmLabel: '确认删除',
                            isDanger: true,
                          );
                          if (ok && context.mounted) await vm.delete(model);
                        },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除本人模型'),
                ),
              ],
            ),
          ],
        ),
      );
}
