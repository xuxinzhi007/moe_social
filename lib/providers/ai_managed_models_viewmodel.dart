import 'package:flutter/foundation.dart';

import '../auth_service.dart';
import '../services/api_service.dart';
import '../services/llm_api_service.dart';

/// 只管理本站当前账号的受管模型，不依赖角色卡是否仍存在。
class AiManagedModelsViewModel extends ChangeNotifier {
  final String? _token = AuthService.token;
  bool _disposed = false;
  bool busy = false;
  Object? error;
  String? notice;
  List<LlmManagedModel> models = [];
  final Map<String, String> _deleteRequests = {};

  bool get accountChanged => AuthService.token != _token;

  Future<void> load() => _run(() async {
        models = await LlmApiService.listManagedModels();
      });

  Future<void> reconcile(LlmManagedModel model) => _run(() async {
        final result = await LlmApiService.reconcileManagedModel(model.agentId);
        _replace(result);
      });

  Future<void> delete(LlmManagedModel model) async {
    if (model.isUnresolved || model.state == 'deleted') return;
    await _run(() async {
      final requestId = _deleteRequests.putIfAbsent(
          model.agentId, LlmApiService.newRequestId);
      final result = await LlmApiService.deleteManagedModel(
          agentId: model.agentId, requestId: requestId);
      _replace(result);
      if (!result.isUnresolved) _deleteRequests.remove(model.agentId);
    });
  }

  void _replace(LlmManagedModel result) {
    models = models
        .map((model) => model.agentId == result.agentId
            ? LlmManagedModel(
                agentId: result.agentId,
                modelName: result.modelName.isEmpty
                    ? model.modelName
                    : result.modelName,
                baseModel: result.baseModel.isEmpty
                    ? model.baseModel
                    : result.baseModel,
                state: result.state,
                requestId: result.requestId.isEmpty
                    ? model.requestId
                    : result.requestId,
                code: result.code,
                message: result.message,
                success: result.success,
                bindingApplied: result.bindingApplied,
                retryable: result.retryable)
            : model)
        .toList();
    notice = result.outcomeMessage;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      if (accountChanged) throw ApiException('账号已切换，请重新打开本人模型管理');
      await action();
      if (accountChanged) throw ApiException('账号已切换，请重新打开本人模型管理');
    } catch (e) {
      error = e;
      if (accountChanged) models = [];
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
