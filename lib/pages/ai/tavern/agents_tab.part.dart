part of '../agent_list_page.dart';

extension TavernAgentsTabPart on _AgentListPageState {
  Widget tavernBuildFilterPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 10),
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
                    child: Text(option, style: const TextStyle(fontSize: 12)),
                  ),
                )
                .toList(),
            decoration: InputDecoration(
              labelText: '排序',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              filled: true,
              fillColor: const Color(0xFFF8F9FD),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          const SizedBox(width: 10),
          Expanded(
            child: tavernStatCard(
              title: '服务器模型',
              value: '$backendAgents',
              hint: '来自本机推理',
              color: const Color(0xFF5B8DEF),
            ),
          ),
          const SizedBox(width: 10),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: _filteredAgents.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptySearchState())
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的角色',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '共 ${_filteredAgents.length} 个角色',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  _updateTavernState(() => _sortBy = value);
                  _filterAgents();
                },
                icon: Icon(Icons.sort_rounded, size: 16, color: Colors.grey.shade600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, color: Colors.grey[300], size: 54),
          const SizedBox(height: 12),
          Text(
            '没有找到匹配的角色',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
    final agentColor = _agentColors[agent.id] ?? _AgentListPageState._brandPrimary;
    final usageCount = _usageCounts[agent.id] ?? 0;
    final provider = _resolveProviderById(agent.providerProfileId);
    final isBackendProvider = provider.isBuiltinBackend;
    final providerColor = isBackendProvider
        ? const Color(0xFF5B8DEF)
        : const Color(0xFF00A86B);

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
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
                    const SizedBox(height: 8),
                    if (usageCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite_rounded, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
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
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agent.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        agent.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: agentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: providerColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
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
