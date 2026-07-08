import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/ai_lorebook.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/ai_starter_templates.dart';
import '../../widgets/ai/ai_confirm_sheet.dart';
import '../../widgets/ai/ai_empty_state.dart';
import '../../widgets/ai/ai_list_page_layout.dart';
import '../../widgets/ai/ai_list_tile_card.dart';
import '../../widgets/ai/ai_section_header.dart';
import '../../widgets/ai/ai_sheet.dart';
import '../../widgets/ai/ai_status_dot.dart';
import '../../widgets/ai/ai_template_tile.dart';
import '../../widgets/ai/ai_brand_tokens.dart';
import '../../widgets/ai/ai_scaffold.dart';
import '../../widgets/ai/ai_theme.dart';
import '../../widgets/moe_loading.dart';
import '../../widgets/moe_toast.dart';
import 'ai_lorebook_editor_page.dart';
import 'state/lorebooks_list_controller.dart';

/// 世界书列表（统一酒馆子页骨架 + [LorebooksListController]）。
class AiLorebooksPage extends StatefulWidget {
  const AiLorebooksPage({super.key});

  @override
  State<AiLorebooksPage> createState() => _AiLorebooksPageState();
}

class _AiLorebooksPageState extends State<AiLorebooksPage> {
  late final LorebooksListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LorebooksListController()..init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openEditor({AiLorebook? lorebook}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiLorebookEditorPage(lorebook: lorebook),
      ),
    );
    if (result == true && mounted) {
      await _controller.refresh();
    }
  }

  Future<void> _deleteLorebook(AiLorebook lorebook) async {
    final confirmed = await AiConfirmSheet.show(
      context: context,
      title: '删除 Lorebook',
      message: '确定删除「${lorebook.name}」及其全部设定条目吗？',
      confirmLabel: '删除',
      isDanger: true,
    );
    if (!confirmed || !mounted) return;
    await _controller.deleteLorebook(lorebook.id);
    if (!mounted) return;
    MoeToast.success(context, 'Lorebook 已删除');
  }

  Future<void> _createFromTemplate(AiStarterLorebookTemplate template) async {
    HapticFeedback.lightImpact();
    final lorebook = AiStarterTemplates.buildLorebookFromTemplate(template);
    final entries = AiStarterTemplates.buildLorebookEntriesFromTemplate(
      template,
      lorebookId: lorebook.id,
    );
    await AiAgentCloudService().saveLorebook(lorebook, entries);
    if (!mounted) return;
    MoeToast.success(context, '已创建「${template.name}」');
    await _controller.refresh();
  }

  Future<void> _pickStarterTemplate() async {
    final template = await AiSheet.show<AiStarterLorebookTemplate>(
      context: context,
      title: '选择世界书模板',
      subtitle: '模板会预置世界观、地点、规则与关键词',
      child: Builder(
        builder: (sheetContext) => ListView(
          shrinkWrap: true,
          children: AiStarterTemplates.lorebookTemplates
              .map(
                (item) => AiTemplateTile(
                  title: item.name,
                  subtitle: '${item.description} · ${item.entries.length} 条设定',
                  onTap: () => Navigator.pop(sheetContext, item),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (template == null || !mounted) return;
    await _createFromTemplate(template);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        if (c.isInitialLoading) {
          return const AiScaffold(
            title: '世界书',
            body: Center(child: MoeLoading()),
          );
        }

        return AiListPageLayout(
          title: '世界书',
          onRefresh: c.refresh,
          syncStatus: c.syncStatus == AiSyncStatus.idle && c.syncError == null
              ? null
              : c.syncStatus,
          syncLabel: c.syncLabel,
          actions: [
            TextButton.icon(
              onPressed: _pickStarterTemplate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('模板'),
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            backgroundColor: AiBrandTokens.primary,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建'),
          ),
          children: [
            const AiSectionHeader(
              title: '推荐模板',
              subtitle: '点一下即可创建完整世界书，无需等待同步',
            ),
            ...AiStarterTemplates.lorebookTemplates.map(
              (t) => AiTemplateTile(
                title: t.name,
                subtitle: '${t.description} · ${t.entries.length} 条设定',
                onTap: () => _createFromTemplate(t),
              ),
            ),
            AiSectionHeader(
              title: '我的世界书',
              subtitle:
                  c.lorebooks.isEmpty ? null : '共 ${c.lorebooks.length} 本',
            ),
            if (c.lorebooks.isEmpty)
              AiEmptyState(
                icon: Icons.menu_book_outlined,
                title: '还没有自建世界书',
                subtitle: '从上方模板创建，或使用右下角「新建」手动编写。',
                primaryAction: AiEmptyStateAction(
                  label: '新建世界书',
                  icon: Icons.add_rounded,
                  onPressed: () => _openEditor(),
                ),
                secondaryAction: AiEmptyStateAction(
                  label: '浏览模板',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _pickStarterTemplate,
                ),
              )
            else
              ...c.lorebooks.map((lorebook) {
                final count = c.entryCountFor(lorebook.id);
                final desc = lorebook.description.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AiTheme.sectionGap),
                  child: AiListTileCard(
                    title: lorebook.name,
                    subtitle: desc.isEmpty ? '$count 条设定' : '$desc\n$count 条设定',
                    tags: count > 0 ? ['$count 条设定'] : const [],
                    onTap: () => _openEditor(lorebook: lorebook),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          await _openEditor(lorebook: lorebook);
                        } else if (value == 'delete') {
                          await _deleteLorebook(lorebook);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('编辑')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
