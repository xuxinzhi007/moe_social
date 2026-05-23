import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/llama_cpp_connection_probe.dart';
import '../../services/llama_cpp_endpoint_config.dart';
import '../../widgets/moe_toast.dart';

/// 本机 llama.cpp server 连接设置（地址 / 端口 / 测试）。
class LlamaCppSettingsPage extends StatefulWidget {
  const LlamaCppSettingsPage({super.key});

  @override
  State<LlamaCppSettingsPage> createState() => _LlamaCppSettingsPageState();
}

class _LlamaCppSettingsPageState extends State<LlamaCppSettingsPage> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _loading = true;
  bool _testing = false;
  String? _testResult;
  String _resolvedUrl = '';

  bool get _isTunnelHost =>
      LlamaCppEndpointConfig.isTunnelHost(_hostController.text);

  @override
  void initState() {
    super.initState();
    _hostController.addListener(_refreshPreview);
    _portController.addListener(_refreshPreview);
    _load();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (!mounted) return;
    setState(() => _resolvedUrl = _previewRootUrl());
  }

  String _previewRootUrl() {
    final portText = _portController.text.trim();
    final port = portText.isEmpty ? null : int.tryParse(portText);
    return LlamaCppEndpointConfig.composeRootUrl(
      hostInput: _hostController.text,
      port: port,
    );
  }

  Future<void> _load() async {
    final hostOverride = await LlamaCppEndpointConfig.readHostOverride();
    final port = await LlamaCppEndpointConfig.readPortOverride();
    if (!mounted) return;
    setState(() {
      _hostController.text = hostOverride.isNotEmpty
          ? hostOverride
          : LlamaCppEndpointConfig.defaultHost();
      _portController.text =
          port == null ? '${LlamaCppEndpointConfig.defaultPort}' : '$port';
      _resolvedUrl = _previewRootUrl();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final portText = _portController.text.trim();
    int? port;
    if (!_isTunnelHost && portText.isNotEmpty) {
      port = int.tryParse(portText) ?? LlamaCppEndpointConfig.defaultPort;
    }
    await LlamaCppEndpointConfig.saveHostOverride(host);
    await LlamaCppEndpointConfig.savePortOverride(port);
    if (!mounted) return;
    setState(() => _resolvedUrl = _previewRootUrl());
    MoeToast.success(context, '已保存 llama.cpp 地址');
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _save();
      final result = await LlamaCppConnectionProbe.testModels();
      if (!mounted) return;
      setState(() {
        if (result.success) {
          _testResult = result.models.isEmpty
              ? result.message
              : '${result.message}，模型: ${result.models.join(', ')}';
        } else {
          _testResult = result.message;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = '测试异常：$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _pingHealth() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      await _save();
      final result = await LlamaCppConnectionProbe.testHealth();
      if (!mounted) return;
      setState(() => _testResult = result.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'health 检测失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('本机 llama.cpp'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(
                  title: '启动命令（Windows）',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SelectableText(
                        r'.\llama-server.exe -m D:\llm_models\qwen2.gguf '
                        r'--host 0.0.0.0 --port 6633 -ngl 999',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 10),
                        Text(
                          '⚠ 你正在用 Chrome 网页版：经 ngrok 访问 llama-server 可能被浏览器 CORS 拦截。'
                          '推荐用 Windows 桌面 App 测试；网页版请在本机用 127.0.0.1:6633。',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _section(
                  title: '连接地址',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: '服务地址',
                          hintText:
                              'https://xxx.ngrok-free.app 或 127.0.0.1',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (!_isTunnelHost) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Port（本机直连时填写）',
                            hintText: '6633',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '实际请求: $_resolvedUrl/v1/chat/completions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isTunnelHost
                            ? '内网穿透：只需填完整 https 地址，Port 不用填 6633（6633 是本机端口，ngrok 对外走 443）。'
                            : '本机 / 局域网：Host 填 127.0.0.1 或 192.168.x.x，Port 填 6633。\n'
                                'Android 模拟器 Host 用 10.0.2.2。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _save,
                        child: const Text('保存'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('测试 /models'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _testing ? null : _pingHealth,
                    child: const Text('检测 /health'),
                  ),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  _section(
                    title: '测试结果',
                    child: Text(_testResult!),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
