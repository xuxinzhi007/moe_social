import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/llm_endpoint_config.dart';

class LlmTerminalModeSettingsPage extends StatefulWidget {
  const LlmTerminalModeSettingsPage({super.key});

  @override
  State<LlmTerminalModeSettingsPage> createState() =>
      _LlmTerminalModeSettingsPageState();
}

class _LlmTerminalModeSettingsPageState
    extends State<LlmTerminalModeSettingsPage> {
  bool _loading = true;
  bool _enabled = false;
  bool _useBackendProxy = true;
  bool _ignoreAgentSystemPrompt = true;
  late TextEditingController _baseUrlController;

  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await LlmEndpointConfig.isDirectEnabled();
    final baseUrl = await LlmEndpointConfig.getDirectBaseUrl();
    final useProxy = await LlmEndpointConfig.useBackendProxy();
    final ignore = await LlmEndpointConfig.ignoreAgentSystemPrompt();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _baseUrlController.text = baseUrl;
      _useBackendProxy = useProxy;
      _ignoreAgentSystemPrompt = ignore;
      _loading = false;
    });
  }

  Future<void> _saveEnabled(bool v) async {
    setState(() => _enabled = v);
    await LlmEndpointConfig.setDirectEnabled(v);
  }

  Future<void> _saveBaseUrl() async {
    final v = _baseUrlController.text.trim();
    await LlmEndpointConfig.setDirectBaseUrl(v);
  }

  Future<void> _saveUseProxy(bool v) async {
    setState(() => _useBackendProxy = v);
    await LlmEndpointConfig.setUseBackendProxy(v);
  }

  Future<void> _saveIgnore(bool v) async {
    setState(() => _ignoreAgentSystemPrompt = v);
    await LlmEndpointConfig.setIgnoreAgentSystemPrompt(v);
  }

  Uri? _buildTagsUri() {
    final base = _baseUrlController.text.trim().replaceAll(RegExp(r'/+$'), '');
    if (base.isEmpty) return null;
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme) return null;
    return Uri.parse('$base/api/tags');
  }

  Future<void> _testConnection() async {
    Uri uri;
    if (_useBackendProxy) {
      uri = Uri.parse('${LlmEndpointConfig.modelsUri()}');
    } else {
      final u = _buildTagsUri();
      if (u == null) {
        setState(() => _testResult = '地址不合法，请填写如 http://192.168.1.16:11434');
        return;
      }
      uri = u;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      final text = utf8.decode(resp.bodyBytes);
      if (resp.statusCode != 200) {
        setState(() => _testResult = '连接失败：${resp.statusCode}\n$text');
        return;
      }
      final data = jsonDecode(text);
      int count = 0;
      if (data is Map && data['models'] is List) {
        count = (data['models'] as List).length;
      }
      setState(() => _testResult = '连接成功：发现 $count 个模型');
    } catch (e) {
      setState(() => _testResult = '连接出错：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('终端同款（本地 Ollama）'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用本地 Ollama 直连'),
                        subtitle: const Text('开启后将绕过后端包装，尽量对齐终端输出'),
                        value: _enabled,
                        activeColor: primary,
                        onChanged: (v) => _saveEnabled(v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('通过后端转发（推荐：内网穿透场景）'),
                        subtitle: const Text('手机只访问后端(8888)，后端再调用本机 11434'),
                        value: _useBackendProxy,
                        activeColor: primary,
                        onChanged: (v) => _saveUseProxy(v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _baseUrlController,
                        enabled: !_useBackendProxy,
                        decoration: const InputDecoration(
                          labelText: 'Ollama 地址（电脑局域网 IP）',
                          hintText: '例如：http://192.168.1.16:11434',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) {
                          _testResult = null;
                        },
                        onEditingComplete: _saveBaseUrl,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('忽略智能体 System Prompt'),
                        subtitle: const Text('建议开启：避免额外提示词导致输出偏离终端'),
                        value: _ignoreAgentSystemPrompt,
                        activeColor: primary,
                        onChanged: (v) => _saveIgnore(v),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testing
                                  ? null
                                  : () async {
                                      await _saveBaseUrl();
                                      await _testConnection();
                                    },
                              icon: _testing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.wifi_tethering_rounded),
                              label: Text(_testing ? '测试中...' : '测试连接'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7F7FD5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_testResult != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F7FD5).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF7F7FD5).withOpacity(0.18),
                            ),
                          ),
                          child: Text(
                            _testResult!,
                            style: const TextStyle(height: 1.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    '提示：要做到“和电脑终端一致”，手机必须能访问到同一台电脑上的 Ollama。\n'
                    '如果你在外网/内网穿透环境，建议开启“通过后端转发”，无需手机直连 11434。',
                    style: TextStyle(color: Colors.black87, height: 1.35),
                  ),
                ),
              ],
            ),
    );
  }
}

