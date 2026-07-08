part of '../agent_list_page.dart';

extension TavernAgentsTabPart on _AgentListPageState {
  Widget tavernBuildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceXs,
          MoeTokens.spaceLg, MoeTokens.spaceSm),
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
        boxShadow: MoeTokens.shadowMd(),
      ),
      child: Column(
        children: [
          MoeSearchBar(
            hintText: '搜索角色、描述或模型',
            onSearch: (query) {
              _updateTavernState(() => _searchQuery = query);
              _filterAgents();
            },
            onClear: () {
              _updateTavernState(() => _searchQuery = '');
              _filterAgents();
            },
          ),
          const SizedBox(height: MoeTokens.spaceMd),
          DropdownButtonFormField<String>(
            value: _sortBy,
            onChanged: (value) {
              if (value == null) return;
              _updateTavernState(() => _sortBy = value);
              _filterAgents();
            },
            items: _sortOptions
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option,
                        style: const TextStyle(fontSize: MoeTokens.textSm)),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: '排序',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceMd,
                vertical: MoeTokens.spaceMd,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MoeTokens.radiusInput),
              ),
              filled: true,
              fillColor: MoeTokens.pageBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget tavernBuildAgentStatsBar() {
    final customProviders = _agents
        .where((agent) => !_isBackendProviderId(agent.providerProfileId))
        .length;
    final backendAgents = _agents.length - customProviders;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MoeTokens.spaceLg, 0, MoeTokens.spaceLg, MoeTokens.spaceSm),
      child: Row(
        children: [
          Expanded(
            child: tavernStatCard(
              title: '角色池',
              value: '${_filteredAgents.length}',
              hint: '当前可见角色',
              color: _AgentListPageState._brandPrimary,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: tavernStatCard(
              title: '服务器模型',
              value: '$backendAgents',
              hint: '来自本机推理',
              color: MoeTokens.secondary,
            ),
          ),
          const SizedBox(width: MoeTokens.spaceMd),
          Expanded(
            child: tavernStatCard(
              title: '我的 API',
              value: '$customProviders',
              hint: '自定义 Provider',
              color: const Color(0xFF00A86B),
            ),
          ),
        ],
      ),
    );
  }

  Widget tavernStatCard({
    required String title,
    required String value,
    required String hint,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(MoeTokens.spaceMd),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: MoeTokens.shadowSm(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: MoeTokens.bodyText,
              fontSize: MoeTokens.textSm,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: MoeTokens.text2xl,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceXs),
          Text(
            hint,
            style: TextStyle(
              color: MoeTokens.hintText,
              fontSize: MoeTokens.textXs,
            ),
          ),
        ],
      ),
    );
  }

  Widget tavernBuildMyAgentsList() {
    if (_isLoading) {
      return const Center(child: MoeLoading());
    }
    if (_agents.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          _buildSectionHeader(
            title: '从这里开始',
            subtitle: '角色卡保存人设；在「模型来源」选择要调用的模型 ID。',
          ),
          AiEmptyState(
            icon: Icons.nightlife_rounded,
            title: '还没有角色进驻你的酒馆',
            subtitle: '角色卡是身份与人设，不是新建模型。可套用模板后在「模型来源」绑定 API 模型 ID。',
            primaryAction: AiEmptyStateAction(
              label: '新建角色',
              icon: Icons.add_rounded,
              onPressed: () => _openAgentEditor(),
            ),
            secondaryAction: AiEmptyStateAction(
              label: '使用模板',
              icon: Icons.auto_awesome_rounded,
              onPressed: _createFromStarterTemplate,
            ),
          ),
        ],
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildAgentsSectionHeader(),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              MoeTokens.spaceLg, MoeTokens.spaceSm, MoeTokens.spaceLg, 120),
          sliver: _filteredAgents.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptySearchState())
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: MoeTokens.spaceMd,
                    crossAxisSpacing: MoeTokens.spaceMd,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final agent = _filteredAgents[index];
                      return _buildAgentGridCard(agent);
                    },
                    childCount: _filteredAgents.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAgentsSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MoeTokens.spaceLg, MoeTokens.spaceSm,
          MoeTokens.spaceLg, MoeTokens.spaceXs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的角色',
                  style: TextStyle(
                    fontSize: MoeTokens.textLg,
                    fontWeight: FontWeight.w800,
                    color: MoeTokens.titleText,
                  ),
                ),
                const SizedBox(height: MoeTokens.spaceXs),
                Text(
                  '共 ${_filteredAgents.length} 个角色',
                  style: TextStyle(
                    fontSize: MoeTokens.textSm,
                    color: MoeTokens.hintText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: MoeTokens.spaceMd, vertical: MoeTokens.spaceSm),
            decoration: BoxDecoration(
              color: MoeTokens.cardBackground,
              borderRadius: BorderRadius.circular(MoeTokens.radiusMd),
              boxShadow: MoeTokens.shadowSm(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                items: _sortOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          style: const TextStyle(
                              fontSize: MoeTokens.textSm,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateTavernState(() => _sortBy = value);
                  _filterAgents();
                },
                icon: Icon(Icons.sort_rounded,
                    size: MoeTokens.spaceLg, color: MoeTokens.bodyText),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      margin: const EdgeInsets.only(top: MoeTokens.space4xl),
      padding: const EdgeInsets.all(MoeTokens.space3xl),
      decoration: BoxDecoration(
        color: MoeTokens.cardBackground,
        borderRadius: BorderRadius.circular(MoeTokens.radius2xl),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey[300], size: 54),
          const SizedBox(height: MoeTokens.spaceMd),
          Text(
            '没有找到匹配的角色',
            style: TextStyle(
              color: MoeTokens.bodyText,
              fontSize: MoeTokens.textMd,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MoeTokens.spaceSm),
          TextButton(
            onPressed: () {
              _updateTavernState(() => _searchQuery = '');
              _filterAgents();
            },
            child: const Text('清除搜索'),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentGridCard(AiAgent agent) {
    final agentColor =
        _agentColors[agent.id] ?? _AgentListPageState._brandPrimary;
    final usageCount = _usageCounts[agent.id] ?? 0;
    final provider = _resolveProviderById(agent.providerProfileId);
    final isBackendProvider = provider.isBuiltinBackend;
    final providerColor =
        isBackendProvider ? MoeTokens.secondary : const Color(0xFF00A86B);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        unawaited(AiAgentUsageService().increment(agent.id));
        _updateTavernState(() {
          _usageCounts[agent.id] = usageCount + 1;
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(agent: agent),
          ),
        );
      },
      onLongPress: () => _showAgentOptions(agent),
      child: Container(
        decoration: BoxDecoration(
          color: MoeTokens.cardBackground,
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          boxShadow: [
            BoxShadow(
              color: agentColor.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: agentColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(MoeTokens.radiusXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: MoeTokens.spaceXl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      agentColor,
                      agentColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: MoeTokens.spaceSm),
                    if (usageCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: MoeTokens.spaceSm, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius:
                              BorderRadius.circular(MoeTokens.radiusMd),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 10, color: Colors.white),
                            const SizedBox(width: MoeTokens.spaceXs),
                            Text(
                              '$usageCount',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(MoeTokens.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: MoeTokens.textBase,
                          fontWeight: FontWeight.bold,
                          color: MoeTokens.titleText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MoeTokens.spaceXs),
                      Text(
                        agent.description,
                        style: TextStyle(
                          color: MoeTokens.bodyText,
                          fontSize: MoeTokens.textXs,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: MoeTokens.spaceXs,
                        runSpacing: MoeTokens.spaceXs,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: MoeTokens.spaceSm, vertical: 3),
                            decoration: BoxDecoration(
                              color: agentColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(MoeTokens.radiusSm),
                            ),
                            child: Text(
                              agent.modelName.length > 10
                                  ? '${agent.modelName.substring(0, 10)}...'
                                  : agent.modelName,
                              style: TextStyle(
                                color: agentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: MoeTokens.spaceSm, vertical: 3),
                            decoration: BoxDecoration(
                              color: providerColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(MoeTokens.radiusSm),
                            ),
                            child: Text(
                              provider.name.length > 6
                                  ? '${provider.name.substring(0, 6)}...'
                                  : provider.name,
                              style: TextStyle(
                                color: providerColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
