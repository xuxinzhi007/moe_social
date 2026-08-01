import 'pet_avatar_backend.dart';
import 'pet_lpc_composer.dart';
import 'pet_lpc_sheet.dart';
import 'pet_moe_avatar_composer.dart';

/// Sheet 类 avatar（Moe 官方包 / LPC 短跑）统一入口。
abstract final class PetSheetAvatar {
  static bool get isActive {
    final b = resolvePetAvatarBackend();
    return b == PetAvatarBackend.moe || b == PetAvatarBackend.lpc;
  }

  static Future<List<String>> itemIdsForSlot(String slot) async {
    switch (resolvePetAvatarBackend()) {
      case PetAvatarBackend.moe:
        return (await PetMoeAvatarComposer.load()).itemIdsForSlot(slot);
      case PetAvatarBackend.lpc:
        return (await PetLpcComposer.load()).itemIdsForSlot(slot);
      default:
        return const [];
    }
  }

  static Future<PetLpcSheet?> composeOutfit({
    required String hatId,
    required String topId,
    required String bottomId,
    required String shoesId,
  }) async {
    switch (resolvePetAvatarBackend()) {
      case PetAvatarBackend.moe:
        return (await PetMoeAvatarComposer.load()).composeOutfit(
          hatId: hatId,
          topId: topId,
          bottomId: bottomId,
          shoesId: shoesId,
        );
      case PetAvatarBackend.lpc:
        return (await PetLpcComposer.load()).composeOutfit(
          hatId: hatId,
          topId: topId,
          bottomId: bottomId,
          shoesId: shoesId,
        );
      default:
        return null;
    }
  }
}
