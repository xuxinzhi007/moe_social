part of '../agent_list_page.dart';

extension TavernProvidersTabPart on _AgentListPageState {
  Widget tavernBuildAgentSquare() {
    final selectedProvider = _selectedSquareProvider;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildProvidersSectionHeader(),
        ),
        SliverToBoxAdapter(
          child: _buildProviderHorizontalList(),
        ),
        SliverToBoxAdapter(
          child: _buildSelectedProviderDetail(selectedProvider),
        ),
        SliverToBoxAdapter(
          child: _buildModelsSection(selectedProvider),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: _buildModelsList(selectedProvider),
        ),
      ],
    );
  }

  Widget _buildProvidersSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '模型来源',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '选择 API 后绑定模型 ID 创建角色卡',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiProviderProfilesPage()),
              );
              if (mounted) await _reloadPageData();
            },
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('管理', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderHorizontalList() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _providerProfiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final provider = _providerProfiles[index];
          final isSelected = provider.id == _selectedSquareProviderId;
          final isConnected = provider.isBuiltinBackend || provider.baseUrl.isNotEmpty;
          final providerColor = _getProviderColor(provider);

          return GestureDetector(
            onTap: () async {
              _updateTavernState(() => _selectedSquareProviderId = provider.id);
              await AiProviderService().saveLastSelectedProfileId(provider.id);
              await _loadSquareModels();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 130,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? providerColor : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? providerColor
                      : Colors.grey.shade200,
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: providerColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : providerColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getProviderIcon(provider),
                      size: 20,
                      color: isSelected ? Colors.white : providerColor,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    provider.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isConnected
                              ? (isSelected ? Colors.white : const Color(0xFF00A86B))
                              : (isSelected ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade400),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? '已连接' : '未配置',
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getProviderColor(AiProviderProfile provider) {
    if (provider.isBuiltinBackend) {
      return const Color(0xFF5B8DEF);
    }
    if (provider.isOpenAiCompatible) {
      return const Color(0xFF10A37F);
    }
    if (provider.isLlamaCppServer) {
      return const Color(0xFF7C3AED);
    }
    return _AgentListPageState._brandPrimary;
  }

  IconData _getProviderIcon(AiProviderProfile provider) {
    if (provider.isBuiltinBackend) {
      return Icons.cloud_done_rounded;
    }
    if (provider.isLlamaCppServer) {
      return Icons.computer_rounded;
    }
    if (provider.isOpenAiCompatible) {
      return Icons.cloud_outlined;
    }
    return Icons.language_rounded;
  }

  Widget _buildSelectedProviderDetail(AiProviderProfile provider) {
    final sourceLabel = _providerSourceLabel(provider);
    final providerColor = _getProviderColor(provider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: providerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _getProviderIcon(provider),
                    size: 24,
                    color: providerColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sourceLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '刷新模型',
                  onPressed: _loadSquareModels,
                  style: IconButton.styleFrom(
                    backgroundColor: providerColor.withValues(alpha: 0.1),
                    foregroundColor: providerColor,
                  ),
                  icon: _isLoadingSquareModels
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: providerColor,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDetailChip(
                  icon: Icons.layers_rounded,
                  label: '模型数 ${_squareModels.length}',
                  color: providerColor,
                ),
                _buildDetailChip(
                  icon: Icons.link_rounded,
                  label: provider.baseUrl.isEmpty ? '未配置地址' : (provider.baseUrl.length > 25 ? '${provider.baseUrl.substring(0, 25)}...' : provider.baseUrl),
                  color: Colors.blueGrey,
                ),
                if (provider.defaultModel.isNotEmpty)
                  _buildDetailChip(
                    icon: Icons.star_rounded,
                    label: '默认: ${provider.defaultModel}',
                    color: const Color(0xFFE6A700),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelsSection(AiProviderProfile provider) {
    if (_isLoadingSquareModels) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            const MoeLoading(size: 16),
            const SizedBox(width: 10),
            Text(
              '正在加载 ${provider.name} 模型列表...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '可用模型 (${_squareModels.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          if (!provider.isBuiltinBackend || provider.isLlamaCppServer)
            TextButton(
              onPressed: () => _createAgentWithManualModelId(provider),
              child: const Text('手动输入模型ID', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  SliverList _buildModelsList(AiProviderProfile provider) {
    if (_isLoadingSquareModels) {
      return SliverList(
        delegate: SliverChildListDelegate([
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: MoeLoading(),
            ),
          ),
        ]),
      );
    }

    if (_squareModels.isEmpty) {
      return SliverList(
        delegate: SliverChildListDelegate([
          _buildEmptyModelsState(provider),
        ]),
      );
    }

    final categories = tavernCategorizeModels(_squareModels);
    final categoryKeys = categories.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, catIndex) {
          final category = categoryKeys[catIndex];
          final models = categories[category]!;
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${models.length})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              ...models.map((modelName) {
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
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: alreadyAdded
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                          : Colors.grey.shade100,
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
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                alreadyAdded
                                    ? Icons.check_circle_rounded
                                    : Icons.smart_toy_rounded,
                                color: cardColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    modelName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF333333),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tavernGetModelDescription(modelName),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              }),
              if (catIndex == categoryKeys.length - 1)
                const SizedBox(height: 8),
            ],
          );
        },
        childCount: categories.length,
      ),
    );
  }

  Widget _buildEmptyModelsState(AiProviderProfile provider) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _AgentListPageState._brandPrimary.withValues(alpha: 0.8),
                  _AgentListPageState._brandSecondary,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            provider.isBackendOllama
                ? '未找到可用模型'
                : provider.isLlamaCppServer
                    ? '未连接本机 llama.cpp'
                    : '暂无模型列表',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              provider.isBackendOllama
                  ? '请检查 llama-server 是否已启动'
                  : provider.isLlamaCppServer
                      ? '请先启动 llama-server（默认端口 6633）'
                      : '很多中转站不返回 /models，可手动输入模型 ID 创建角色卡',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (provider.isLlamaCppServer)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LlamaCppSettingsPage(),
                      ),
                    );
                    if (mounted) await _reloadPageData();
                  },
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('连接设置', style: TextStyle(fontSize: 12)),
                ),
              FilledButton.icon(
                onPressed: () => _createAgentWithManualModelId(provider),
                style: FilledButton.styleFrom(
                  backgroundColor: _AgentListPageState._brandSecondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: const Icon(Icons.badge_outlined, size: 16),
                label: const Text('手动输入模型ID', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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

    categories.removeWhere((key, value) => value.isEmpty);

    return categories;
  }

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
