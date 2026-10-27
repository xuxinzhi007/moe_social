import 'package:flutter/foundation.dart';

import '../../game/life/life_flame_game.dart';
import '../../services/companion_service.dart';
import '../../services/life_service.dart';

const String campCareFeed = 'feed';
const String campCarePet = 'pet';

/// 把一份世界快照推进院子舞台。调用方负责在 [LifeFlameGame.hasLayout] 之后调用。
void syncCampStage(
  LifeFlameGame game,
  LifeInitialState state, {
  required int? selectedId,
}) {
  game.setBoundEntityId(selectedId);
  game.syncEntities(state.entities, selectedId: selectedId);
  game.syncRecentEvents(state.events.take(8).toList(growable: false));
  if (selectedId != null) {
    game.focusEntity(selectedId);
  }
}

/// 照料成功后播放院子演出，并给伙伴亲密度记一次 care。
/// 冷却或连点只走角色台词。返回是否完成了一次成功照料。
Future<bool> applyCampCare({
  required LifeFlameGame game,
  required int entityId,
  required String action,
}) async {
  if (game.isCareBusy(entityId)) {
    game.playBusyCareReply(entityId, action);
    return false;
  }
  try {
    final result = await LifeService.postLifeAction(action, entityId);
    if (!_lifeActionSucceeded(result)) {
      game.playBusyCareReply(entityId, action);
      return false;
    }
  } on LifeActionCooldownException {
    game.playBusyCareReply(entityId, action);
    return false;
  } catch (error) {
    debugPrint('camp care failed: $error');
    return false;
  }
  game.playCarePerformance(entityId, action);
  try {
    await CompanionService().bumpIntimacy(reason: 'care');
  } catch (error) {
    debugPrint('companion intimacy bump skipped: $error');
  }
  return true;
}

bool _lifeActionSucceeded(Map<String, dynamic> result) {
  if (result['success'] == false || result['ok'] == false) return false;
  final data = result['data'];
  if (data is Map && data['success'] == false) return false;
  return true;
}
