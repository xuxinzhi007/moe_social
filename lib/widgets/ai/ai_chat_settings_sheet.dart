import 'package:flutter/material.dart';

import '../../models/ai_agent.dart';
import '../../services/ai_agent_cloud_service.dart';
import '../../services/llm_api_service.dart';
import 'ai_brand_tokens.dart';
import 'ai_sheet.dart';
import 'ai_theme.dart';

const _parameterLabels = <String, String>{
  'temperature': '温度',
  'top_p': 'Top P',
  'top_k': 'Top K',
  'presence_penalty': '存在惩罚',
  'repeat_penalty': '重复惩罚',
  'frequency_penalty': '频率惩罚',
  'min_p': 'Min P',
};

/// 聊天页设置：切换模型、思考开关、上下文状态，以及角色派生模型。
abstract final class AiChatSettingsSheet {
  static Future<void> show({
    required BuildContext context,
    required AiAgent agent,
    required ValueChanged<AiAgent> onAgentChanged,
  }) {
    return AiSheet.show(
      context: context,
      title: '对话设置',
      subtitle: agent.name,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      child: _ChatModelSettings(agent: agent, onAgentChanged: onAgentChanged),
    );
  }
}

class _ChatModelSettings extends StatefulWidget {
  const _ChatModelSettings({
    required this.agent,
    required this.onAgentChanged,
  });

  final AiAgent agent;
  final ValueChanged<AiAgent> onAgentChanged;

  @override
  State<_ChatModelSettings> createState() => _ChatModelSettingsState();
}

class _ChatModelSettingsState extends State<_ChatModelSettings> {
  List<LlmCatalogModel> _catalog = const [];
  bool _loading = true;
  String? _error;
  bool _saving = false;
  bool _advanced = false;
  late AiAgent _agent;
  late final TextEditingController _promptController;
  String _baseModel = '';
  Map<String, double> _parameters = {};

  @override
  void initState() {
    super.initState();
    _agent = widget.agent;
    _promptController = TextEditingController(text: widget.agent.systemPrompt);
    _load();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  LlmCatalogModel? get _selected {
    for (final item in _catalog) {
      if (item.name == _agent.modelName) return item;
    }
    return null;
  }

  List<LlmCatalogModel> get _bases =>
      _catalog.where((item) => !item.derived).toList();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final catalog = await LlmApiService.fetchCatalog();
      if (!mounted) return;
      final bases = catalog.where((item) => !item.derived).toList();
      final current = _selectedFrom(catalog, _agent.modelName);
      final baseName = current != null && !current.derived
          ? current.name
          : (bases.isNotEmpty ? bases.first.name : '');
      setState(() {
        _catalog = catalog;
        _baseModel = baseName;
        _loading = false;
      });
      if (current != null && current.derived) {
        try {
          final managed = await LlmApiService.listManagedModels();
          for (final item in managed) {
            if (item.agentId == _agent.id && item.baseModel.isNotEmpty) {
              if (mounted) setState(() => _baseModel = item.baseModel);
              break;
            }
          }
        } catch (_) {}
        await _loadBaseCard(current.name, replacePrompt: true);
      } else if (baseName.isNotEmpty) {
        await _loadBaseCard(baseName, replacePrompt: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '模型列表读取失败：$error';
      });
    }
  }

  LlmCatalogModel? _selectedFrom(List<LlmCatalogModel> catalog, String name) {
    for (final item in catalog) {
      if (item.name == name) return item;
    }
    return null;
  }

  Future<void> _loadBaseCard(String model,
      {required bool replacePrompt}) async {
    try {
      final card = await LlmApiService.fetchModelCard(model);
      if (!mounted) return;
      setState(() {
        _parameters = Map<String, double>.from(card.parameters);
        if (replacePrompt && card.systemPrompt.isNotEmpty) {
          _promptController.text = card.systemPrompt;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _parameters = {});
    }
  }

  Future<void> _persist(AiAgent next) async {
    setState(() => _saving = true);
    try {
      await AiAgentCloudService().updateAgent(next);
      if (!mounted) return;
      setState(() {
        _agent = next;
        _saving = false;
      });
      widget.onAgentChanged(next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存角色失败：$error';
      });
    }
  }

  Future<void> _selectModel(String name) async {
    if (name == _agent.modelName) return;
    await _persist(_agent.copyWith(modelName: name));
  }

  Future<void> _saveDerived() async {
    if (_baseModel.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final view = await LlmApiService.upsertAgentPrompt(
        agentId: _agent.id,
        requestId: LlmApiService.newRequestId(),
        baseModel: _baseModel,
        systemPrompt: _promptController.text.trim(),
        parameters: _advanced ? _parameters : const {},
      );
      if (view.modelName.isEmpty || view.state == 'failed') {
        throw Exception(view.message.isEmpty ? '模型未就绪' : view.message);
      }
      final next = _agent.copyWith(modelName: view.modelName);
      await AiAgentCloudService().updateAgent(next);
      if (!mounted) return;
      setState(() {
        _agent = next;
        _saving = false;
      });
      widget.onAgentChanged(next);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存派生模型失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final selected = _selected;
    final contextLength = selected?.contextLength ?? 0;
    final canThink = selected?.thinking == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(_error!, style: AiTheme.caption.copyWith(color: Colors.red)),
          const SizedBox(height: 8),
        ],
        Text('当前模型', style: AiTheme.title.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey(selected?.name),
          initialValue: selected?.name,
          items: [
            for (final item in _catalog)
              DropdownMenuItem(value: item.name, child: Text(item.name)),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value != null) _selectModel(value);
                },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Text(
          contextLength > 0 ? '上下文 $contextLength' : '上下文未返回',
          style: AiTheme.caption.copyWith(color: Colors.grey.shade600),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('思考'),
          subtitle: Text(canThink ? '按这个角色记住开关' : '当前模型没有思考能力'),
          value: canThink && _agent.thinkEnabled,
          onChanged: !canThink || _saving
              ? null
              : (value) => _persist(_agent.copyWith(thinkEnabled: value)),
        ),
        const Divider(),
        Text('角色派生模型', style: AiTheme.title.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text(
          '保存后覆盖这个角色自己的模型，不改基座。',
          style: AiTheme.caption.copyWith(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('base-$_baseModel'),
          initialValue: _bases.any((item) => item.name == _baseModel)
              ? _baseModel
              : null,
          items: [
            for (final item in _bases)
              DropdownMenuItem(value: item.name, child: Text(item.name)),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _baseModel = value);
                  _loadBaseCard(value, replacePrompt: false);
                },
          decoration: const InputDecoration(
            labelText: '基座',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: '系统提示词',
            border: OutlineInputBorder(),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('高级参数'),
          subtitle: const Text('写入模型，聊天请求不再覆盖'),
          value: _advanced,
          onChanged:
              _saving ? null : (value) => setState(() => _advanced = value),
        ),
        if (_advanced && _parameters.isEmpty)
          Text(
            '基座没有返回可调采样参数。',
            style: AiTheme.caption.copyWith(color: Colors.grey.shade600),
          ),
        if (_advanced)
          for (final entry in _parameterLabels.entries)
            if (_parameters.containsKey(entry.key))
              _ParameterSlider(
                label: entry.value,
                value: _parameters[entry.key]!,
                spec: _specFor(entry.key),
                onChanged: (value) {
                  setState(() => _parameters[entry.key] = value);
                },
              ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving || _baseModel.isEmpty ? null : _saveDerived,
          style: FilledButton.styleFrom(
            backgroundColor: AiBrandTokens.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(_saving ? '保存中' : '保存派生模型'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RangeSpec {
  const _RangeSpec(this.min, this.max, this.divisions);
  final double min;
  final double max;
  final int divisions;
}

_RangeSpec _specFor(String key) {
  return switch (key) {
    'temperature' => const _RangeSpec(0, 2, 40),
    'top_k' => const _RangeSpec(1, 100, 99),
    'presence_penalty' ||
    'repeat_penalty' ||
    'frequency_penalty' =>
      const _RangeSpec(-2, 2, 40),
    _ => const _RangeSpec(0, 1, 20),
  };
}

class _ParameterSlider extends StatelessWidget {
  const _ParameterSlider({
    required this.label,
    required this.value,
    required this.spec,
    required this.onChanged,
  });

  final String label;
  final double value;
  final _RangeSpec spec;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = value.clamp(spec.min, spec.max);
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label, style: AiTheme.caption)),
        Expanded(
          child: Slider(
            value: shown,
            min: spec.min,
            max: spec.max,
            divisions: spec.divisions,
            activeColor: AiBrandTokens.primary,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            shown.toStringAsFixed(shown >= 10 ? 0 : 2),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
