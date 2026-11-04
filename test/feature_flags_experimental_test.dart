import 'package:flutter_test/flutter_test.dart';
import 'package:moe_social/constants/feature_flags.dart';

void main() {
  test('experimental surfaces follow the master switch (on for 内测/侧载)', () {
    // 本分支为侧载内测打开实验总开关；商店包发布前须改回 false。
    expect(FeatureFlags.showExperimentalFeatures, isTrue);
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
