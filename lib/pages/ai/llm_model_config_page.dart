import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/api_service.dart';
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
      final uri = Uri.parse('${ApiService.baseUrl}/api/llm/config');
      ApiService.logDirectHttp('GET', uri);
      final response = await http
          .get(
            uri,
            headers: ApiService.mergeTunnelHeaders(
              uri,
              headers: {
                if (ApiService.token case final t?)
                  'Authorization': 'Bearer $t',
              },
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        throw Exception('请求失败: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw Exception('响应格式异常');
      }
      final data = decoded['data'];
      if (data is! Map) {
        throw Exception('配置数据为空');
      }

      final ollama = data['ollama'];
      final memoryBudget = data['memory_budget'];
      if (ollama is! Map || memoryBudget is! Map) {
        throw Exception('配置字段缺失');
      }

      if (!mounted) return;
      setState(() {
        _terminalModeEnabled = terminalMode;
        _ollama = Map<String, dynamic>.from(ollama);
        _memoryBudget = Map<String, dynamic>.from(memoryBudget);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
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
      backgroundColor: const Color(0xFFF5F7FA),
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
                          _kv('Ollama Base URL',
                              '${_ollama?['base_url'] ?? '-'}'),
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
