import 'package:flutter/services.dart';
import '../models/gift.dart';

enum HapticType {
  selection,
  confirmation,
  success,
  luxury,
  combo,
}

class GiftHapticFeedback {
  static bool _enabled = true;

  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  static bool get isEnabled => _enabled;

  static Future<bool> isSupported() async {
    try {
      return await SystemChannels.platform.invokeMethod<bool>('HapticFeedback.isSupported') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> light() async {
    if (!_enabled) return;
    await HapticFeedback.lightImpact();
  }

  static Future<void> medium() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selection() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> vibrate() async {
    if (!_enabled) return;
    await HapticFeedback.vibrate();
  }

  static Future<void> trigger(HapticType type) async {
    if (!_enabled) return;

    switch (type) {
      case HapticType.selection:
        await light();
        break;
      case HapticType.confirmation:
        await medium();
        break;
      case HapticType.success:
        await medium();
        break;
      case HapticType.luxury:
        await heavy();
        await Future.delayed(const Duration(milliseconds: 100));
        await heavy();
        await Future.delayed(const Duration(milliseconds: 100));
        await heavy();
        break;
      case HapticType.combo:
        await medium();
        await Future.delayed(const Duration(milliseconds: 50));
        await light();
        await Future.delayed(const Duration(milliseconds: 50));
        await medium();
        break;
    }
  }

  static Future<void> forGiftSelection(Gift gift) async {
    await trigger(HapticType.selection);
  }

  static Future<void> forGiftConfirmation(Gift gift) async {
    await trigger(HapticType.confirmation);
  }

  static Future<void> forGiftSuccess(Gift gift) async {
    if (gift.level == GiftLevel.luxury) {
      await trigger(HapticType.luxury);
    } else {
      await trigger(HapticType.success);
    }
  }

  static Future<void> forCombo(int comboCount) async {
    if (comboCount > 1) {
      await trigger(HapticType.combo);
    }
  }
}
