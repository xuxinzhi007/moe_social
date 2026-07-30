import 'package:flutter/material.dart';
import '../../theme/moe_tokens.dart';

import '../../services/llm_api_service.dart';
import '../../services/llm_endpoint_config.dart';

class LlmModelConfigPage extends StatefulWidget {
  const LlmModelConfigPage({super.key});

  @override
  State<LlmModelConfigPage> createState() => _LlmModelConfigPageState();
}

class _LlmModelConfigPageState extends State<LlmModelConfigPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _ollama;
  Map<String, dynamic>? _memoryBudget;
  Map<String, dynamic>? _runtime;
  bool _terminalModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final terminalMode = await LlmEndpointConfig.isTerminalModeEnabled();
      final data = await LlmApiService.getConfig();

      final inference = data['llm_inference'] ?? data['ollama'];
      final memoryBudget = data['memory_budget'];
      final runtime = data['runtime'];
      if (inference is! Map || memoryBudget is! Map) {
        throw Exception('配置字段缺失');
      }

      if (!mounted) return;
      setState(() {
        _terminalModeEnabled = terminalMode;
        _ollama = Map<String, dynamic>.from(inference);
        _memoryBudget = Map<String, dynamic>.from(memoryBudget);
        if (runtime is Map) {
          _runtime = Map<String, dynamic>.from(runtime);
        } else {
          _runtime = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MoeTokens.pageBackground,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('AI 模型配置'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新配置',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '加载失败：$_error',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前模式',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _kv('终端同款模式', _terminalModeEnabled ? '已开启' : '已关闭'),
                          _kv(
                            '聊天接口',
                            _terminalModeEnabled
                                ? '/api/llm/chat/raw'
                                : '/api/llm/chat',
                          ),
                          _kv(
                            '服务端记忆是否生效',
                            _terminalModeEnabled ? '否（raw 调试）' : '是',
                          ),
                          _kv(
                            'raw 调试边界',
                            (_runtime?['raw_debug_only'] == true)
                                ? '仅调试用途'
                                : '未声明',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '后端生效模型配置',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _kv('推理服务地址', '${_ollama?['base_url'] ?? '-'}'),
                          _kv('API 风格', '${_ollama?['api_style'] ?? 'openai'}'),
                          _kv('请求超时（秒）',
                              '${_ollama?['timeout_seconds'] ?? '-'}'),
                          _kv(
                            '记忆/摘要模型',
                            (_ollama?['memory_model'] as String?)?.isNotEmpty ==
                                    true
                                ? '${_ollama?['memory_model']}'
                                : '跟随聊天模型',
                          ),
                          _kv(
                            '自定义总结提示词',
                            (_ollama?['has_summary_prompt'] == true)
                                ? '已配置'
                                : '未配置',
                          ),
                          _kv(
                            '自定义抽取提示词',
                            (_ollama?['has_extract_prompt'] == true)
                                ? '已配置'
                                : '未配置',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '记忆额度（后端预算）',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _kv('每轮注入记忆条数上限',
                              '${_memoryBudget?['max_injected_memory_items'] ?? '-'}'),
                          _kv('每轮注入记忆字符上限',
                              '${_memoryBudget?['max_injected_memory_runes'] ?? '-'}'),
                          _kv('触发摘要历史阈值',
                              '${_memoryBudget?['max_history_messages'] ?? '-'}'),
                          _kv('保留最近消息数',
                              '${_memoryBudget?['keep_recent_messages'] ?? '-'}'),
                          _kv('上下文总预算 token',
                              '${_memoryBudget?['max_ctx_tokens'] ?? '-'}'),
                          _kv('安全使用比例',
                              '${_memoryBudget?['ctx_safe_ratio'] ?? '-'}'),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
