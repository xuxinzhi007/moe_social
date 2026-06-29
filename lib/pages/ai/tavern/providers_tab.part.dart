part of '../agent_list_page.dart';

extension TavernProvidersTabPart on _AgentListPageState {
  Widget tavernBuildAgentSquare() {
    final provider = _selectedSquareProvider;
    final sourceLabel = _providerSourceLabel(provider);

    Widget body;
    if (_isLoadingSquareModels) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MoeLoading(),
          const SizedBox(height: 12),
          Text(
            '正在加载 ${provider.name} 模型列表...',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ],
      );
    } else if (_squareModels.isEmpty) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF86A8E7), Color(0xFF91EAE4)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF86A8E7).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            provider.isBackendOllama
                ? '未找到可用模型'
                : provider.isLlamaCppServer
                    ? '未连接本机 llama.cpp'
                    : '接口已连通，但暂无模型列表',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              provider.isBackendOllama
                  ? '请检查本机 llama-server 是否已启动（默认 6633）'
                  : provider.isLlamaCppServer
                      ? '请先启动 llama-server（默认端口 6633），并在「模型来源 → 本机 llama.cpp → 设置」检查地址。\n'
                          '模型 ID 通常与 gguf 文件名一致，例如 qwen2。'
                      : '很多中转站不返回 /models，这很正常。\n'
                          '请到 Provider 填写「默认模型」或「手动模型」（一行一个），'
                          '保存后即可在此创建角色卡；聊天时直接调用该模型 ID。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 14, height: 1.45),
            ),
          ),
          const SizedBox(height: 24),
          if (!provider.isBackendOllama) ...[
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AiProviderProfilesPage(),
                  ),
                );
                if (mounted) await _reloadPageData();
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('去配置 Provider'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _createAgentWithManualModelId(provider),
              style: FilledButton.styleFrom(
                backgroundColor: _AgentListPageState._brandSecondary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('直接输入模型 ID 创建角色卡'),
            ),
            const SizedBox(height: 10),
          ],
          ElevatedButton.icon(
            onPressed: _loadSquareModels,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新加载'),
            style: ElevatedButton.styleFrom(
              backgroundColor: provider.isBackendOllama
                  ? _AgentListPageState._brandSecondary
                  : null,
              foregroundColor: provider.isBackendOllama ? Colors.white : null,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      );
    } else {
      final modelCategories = tavernCategorizeModels(_squareModels);
      body = ListView.builder(
        itemCount: modelCategories.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemBuilder: (context, categoryIndex) {
          final category = modelCategories.keys.elementAt(categoryIndex);
          final categoryModels = modelCategories[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _AgentListPageState._brandSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${categoryModels.length})',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: categoryModels.map((modelName) {
                  final existing = _findExistingAgentForModel(
                    modelName,
                    providerId: provider.id,
                  );
                  final alreadyAdded = existing != null;
                  final cardColor = alreadyAdded
                      ? const Color(0xFF4CAF50)
                      : (provider.isBuiltinBackend
                          ? _AgentListPageState._brandSecondary
                          : const Color(0xFF00A86B));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: cardColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _createAgentFromModel(modelName, provider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      cardColor,
                                      cardColor.withValues(alpha: 0.7)
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: cardColor.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  alreadyAdded
                                      ? Icons.check_circle_rounded
                                      : Icons.badge_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            modelName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF333333),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (alreadyAdded)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              '已有角色卡',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF4CAF50),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tavernGetModelDescription(modelName),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            sourceLabel,
                                            style: TextStyle(
                                              color: cardColor,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            provider.name,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tavernGetModelSize(modelName),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                alreadyAdded
                                    ? Icons.chat_bubble_outline_rounded
                                    : Icons.add_circle_outline_rounded,
                                color: cardColor,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildSectionHeader(
          title: '模型来源',
          subtitle: '选择 API 后绑定模型 ID 创建角色卡；/models 为空时请先在 Provider 填默认或手动模型。',
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _providerProfiles.any(
                        (item) => item.id == _selectedSquareProviderId,
                      )
                          ? _selectedSquareProviderId
                          : AiProviderProfile.builtinBackendId,
                      decoration: InputDecoration(
                        labelText: '当前模型来源',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FD),
                      ),
                      isExpanded: true,
                      items: _providerProfiles
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        _updateTavernState(
                          () => _selectedSquareProviderId = value,
                        );
                        await AiProviderService()
                            .saveLastSelectedProfileId(value);
                        await _loadSquareModels();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: '刷新模型',
                    onPressed: _loadSquareModels,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    tavernSquareMetaChip(
                      'Provider：${provider.name}',
                      _AgentListPageState._brandPrimary,
                    ),
                    tavernSquareMetaChip('来源：$sourceLabel', Colors.blueGrey),
                    tavernSquareMetaChip('模型数：${_squareModels.length}',
                        _AgentListPageState._brandSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }

  Widget tavernSquareMetaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // 模型分类
  Map<String, List<String>> tavernCategorizeModels(List<String> models) {
    final categories = <String, List<String>>{
      '通用模型': [],
      '专业模型': [],
      '创意模型': [],
      '其他模型': [],
    };

    for (final model in models) {
      if (model.contains('llama') ||
          model.contains('gemma') ||
          model.contains('mistral')) {
        categories['通用模型']!.add(model);
      } else if (model.contains('code') ||
          model.contains('math') ||
          model.contains('scientific')) {
        categories['专业模型']!.add(model);
      } else if (model.contains('creative') ||
          model.contains('art') ||
          model.contains('writing')) {
        categories['创意模型']!.add(model);
      } else {
        categories['其他模型']!.add(model);
      }
    }

    // 移除空分类
    categories.removeWhere((key, value) => value.isEmpty);

    return categories;
  }

  // 获取模型描述
  String tavernGetModelDescription(String model) {
    if (model.contains('llama')) {
      return 'Meta的大型语言模型，适用于多种任务';
    } else if (model.contains('gemma')) {
      return 'Google的轻量级语言模型，性能优异';
    } else if (model.contains('mistral')) {
      return 'Mistral AI的高效语言模型，推理能力强';
    } else if (model.contains('code')) {
      return '专门用于代码生成和理解的模型';
    } else if (model.contains('creative')) {
      return '擅长创意写作和内容生成的模型';
    } else {
      return '通用AI模型，可用于多种任务';
    }
  }

  // 获取模型大小
  String tavernGetModelSize(String model) {
    if (model.contains('7b') || model.contains('8b')) {
      return '小模型';
    } else if (model.contains('13b') || model.contains('14b')) {
      return '中模型';
    } else if (model.contains('34b') || model.contains('70b')) {
      return '大模型';
    } else {
      return '未知大小';
    }
  }
}
