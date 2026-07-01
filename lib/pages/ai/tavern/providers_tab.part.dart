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
          const SizedBox(height: MoeTokens.spaceMd),
          Text(
            '正在加载 ${provider.name} 模型列表...',
            style: TextStyle(color: MoeTokens.bodyText, fontSize: MoeTokens.textBase),
          ),
        ],
      );
    } else if (_squareModels.isEmpty) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(MoeTokens.space4xl),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [MoeTokens.secondary, MoeTokens.accent],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MoeTokens.secondary.withValues(alpha: 0.3),
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
          const SizedBox(height: MoeTokens.space2xl),
          Text(
            provider.isBackendOllama
                ? '未找到可用模型'
                : '接口已连通，但暂无模型列表',
            style: TextStyle(color: MoeTokens.bodyText, fontSize: MoeTokens.textLg),
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MoeTokens.space2xl),
            child: Text(
              provider.isBackendOllama
                  ? '请检查后端推理服务是否已启动'
                  : '很多中转站不返回 /models，这很正常。\n'
                      '请到 Provider 填写「默认模型」或「手动模型」（一行一个），'
                      '保存后即可在此创建角色卡；聊天时直接调用该模型 ID。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: MoeTokens.hintText, fontSize: MoeTokens.textBase, height: 1.45),
            ),
          ),
          const SizedBox(height: MoeTokens.space2xl),
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
            const SizedBox(height: MoeTokens.spaceMd),
            FilledButton.icon(
              onPressed: () => _createAgentWithManualModelId(provider),
              style: FilledButton.styleFrom(
                backgroundColor: _AgentListPageState._brandSecondary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: MoeTokens.space3xl, vertical: MoeTokens.spaceMd),
              ),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('直接输入模型 ID 创建角色卡'),
            ),
            const SizedBox(height: MoeTokens.spaceMd),
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
              padding: const EdgeInsets.symmetric(horizontal: MoeTokens.space3xl, vertical: MoeTokens.spaceMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
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
        padding: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, 0, MoeTokens.spaceLg, MoeTokens.spaceLg),
        itemBuilder: (context, categoryIndex) {
          final category = modelCategories.keys.elementAt(categoryIndex);
          final categoryModels = modelCategories[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: MoeTokens.spaceSm),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _AgentListPageState._brandSecondary,
                        borderRadius: BorderRadius.circular(MoeTokens.radiusSm),
                      ),
                    ),
                    const SizedBox(width: MoeTokens.spaceSm),
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: MoeTokens.textBase,
                        fontWeight: FontWeight.bold,
                        color: MoeTokens.titleText,
                      ),
                    ),
                    const SizedBox(width: MoeTokens.spaceSm),
                    Text(
                      '(${categoryModels.length})',
                      style: TextStyle(
                        fontSize: MoeTokens.textSm,
                        color: MoeTokens.hintText,
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
                    margin: const EdgeInsets.only(bottom: MoeTokens.spaceMd),
                    decoration: BoxDecoration(
                      color: MoeTokens.cardBackground,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      boxShadow: MoeTokens.shadowSm(),
                      border: Border.all(
                        color: cardColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _createAgentFromModel(modelName, provider);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(MoeTokens.spaceMd),
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
                              const SizedBox(width: MoeTokens.spaceMd),
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
                                              fontSize: MoeTokens.textBase,
                                              fontWeight: FontWeight.bold,
                                              color: MoeTokens.titleText,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (alreadyAdded)
                                          Container(
                                            margin:
                                                const EdgeInsets.only(left: MoeTokens.spaceSm),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: MoeTokens.spaceSm,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF4CAF50)
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(MoeTokens.radiusSm),
                                            ),
                                            child: const Text(
                                              '已有角色卡',
                                              style: TextStyle(
                                                fontSize: MoeTokens.textXs,
                                                color: Color(0xFF4CAF50),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: MoeTokens.spaceXs),
                                    Text(
                                      tavernGetModelDescription(modelName),
                                      style: TextStyle(
                                        color: MoeTokens.bodyText,
                                        fontSize: MoeTokens.textXs,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: MoeTokens.spaceSm),
                                    Wrap(
                                      spacing: MoeTokens.spaceSm,
                                      runSpacing: MoeTokens.spaceSm,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: MoeTokens.spaceSm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cardColor.withValues(
                                                alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(MoeTokens.radiusSm),
                                          ),
                                          child: Text(
                                            sourceLabel,
                                            style: TextStyle(
                                              color: cardColor,
                                              fontSize: MoeTokens.textXs,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: MoeTokens.spaceSm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(MoeTokens.radiusSm),
                                          ),
                                          child: Text(
                                            provider.name,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: MoeTokens.textXs,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: MoeTokens.spaceSm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius:
                                                BorderRadius.circular(MoeTokens.radiusSm),
                                          ),
                                          child: Text(
                                            tavernGetModelSize(modelName),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: MoeTokens.textXs,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: MoeTokens.spaceSm),
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
          margin: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, 0, MoeTokens.spaceLg, MoeTokens.spaceLg),
          padding: const EdgeInsets.all(MoeTokens.spaceXl),
          decoration: BoxDecoration(
            color: MoeTokens.cardBackground,
            borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
            boxShadow: MoeTokens.shadowMd(),
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
                          borderRadius: BorderRadius.circular(MoeTokens.radiusLg),
                        ),
                        filled: true,
                        fillColor: MoeTokens.pageBackground,
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
                  const SizedBox(width: MoeTokens.spaceMd),
                  IconButton.filledTonal(
                    tooltip: '刷新模型',
                    onPressed: _loadSquareModels,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: MoeTokens.spaceMd),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: MoeTokens.spaceSm,
                  runSpacing: MoeTokens.spaceSm,
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
      padding: const EdgeInsets.symmetric(horizontal: MoeTokens.spaceMd, vertical: MoeTokens.spaceSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(MoeTokens.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: MoeTokens.textXs,
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
