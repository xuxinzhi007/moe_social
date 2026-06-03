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
          _buildHeroCard(),
          _buildTemplateChipRow(),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildHeroCard(),
        _buildTemplateChipRow(),
        _buildSectionHeader(
          title: '角色剧场',
          subtitle: '角色、模型来源与酒馆设定都在这里汇总管理。',
        ),
        tavernBuildFilterPanel(),
        tavernBuildAgentStatsBar(),
        if (_filteredAgents.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded,
                    color: Colors.grey[300], size: 54),
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
          )
        else
          ListView.builder(
            itemCount: _filteredAgents.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (context, index) {
              final agent = _filteredAgents[index];
              final agentColor =
                  _agentColors[agent.id] ?? _AgentListPageState._brandPrimary;
              final usageCount = _usageCounts[agent.id] ?? 0;
              final provider = _resolveProviderById(agent.providerProfileId);
              final isBackendProvider = provider.isBuiltinBackend;
              final providerColor = isBackendProvider
                  ? const Color(0xFF5B8DEF)
                  : const Color(0xFF00A86B);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: agentColor.withValues(alpha: 0.2),
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
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // 智能体头像
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  agentColor,
                                  agentColor.withValues(alpha: 0.7)
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: agentColor.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              color: Colors.white,
                              size: 28,
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
                                        agent.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF333333),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (usageCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '使用 $usageCount 次',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  agent.description,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
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
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            agentColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        agent.modelName,
                                        style: TextStyle(
                                          color: agentColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: providerColor.withValues(
                                            alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        provider.name,
                                        style: TextStyle(
                                          color: providerColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _providerSourceLabel(provider),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${agent.createdAt.year}-${agent.createdAt.month}-${agent.createdAt.day}',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: '管理角色卡',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: () => _showAgentOptions(agent),
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
