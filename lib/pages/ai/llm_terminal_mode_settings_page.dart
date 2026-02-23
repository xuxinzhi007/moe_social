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

  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() => super.dispose();

  Future<void> _load() async {
    final enabled = await LlmEndpointConfig.isTerminalModeEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _saveEnabled(bool v) async {
    setState(() => _enabled = v);
    await LlmEndpointConfig.setTerminalModeEnabled(v);
  }

  Future<void> _testConnection() async {
    final uri = await LlmEndpointConfig.modelsUri();
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
      setState(() => _testResult = '连接成功：后端 raw 转发可用');
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
                        title: const Text('启用终端同款（后端 raw 转发）'),
                        subtitle: const Text('默认开启：不注入记忆/总结，最大程度贴近终端输出'),
                        value: _enabled,
                        activeColor: primary,
                        onChanged: (v) => _saveEnabled(v),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testing
                                  ? null
                                  : () async {
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
                    '当前模式通过后端(8888/cpolar)转发到本机 Ollama(11434)，手机无需直接连 11434。',
                    style: TextStyle(color: Colors.black87, height: 1.35),
                  ),
                ),
              ],
            ),
    );
  }
}

