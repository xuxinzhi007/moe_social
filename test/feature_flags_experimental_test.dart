import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/constants/feature_flags.dart';

void main() {
  test('experimental surfaces stay behind the master switch', () {
    expect(FeatureFlags.showExperimentalFeatures, isFalse);
    expect(
      FeatureFlags.replyAssistPrototype,
      FeatureFlags.showExperimentalFeatures,
    );
    expect(FeatureFlags.showAutoGlm, FeatureFlags.showExperimentalFeatures);
    expect(FeatureFlags.liveGiftPk, FeatureFlags.showExperimentalFeatures);
    expect(
      FeatureFlags.showGameNetworkLab,
      FeatureFlags.showExperimentalFeatures,
    );
  });
}
