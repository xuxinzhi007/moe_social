class FeatureFlags {
  const FeatureFlags._();

  static const bool showExperimentalFeatures = false;
  static const bool showLocalModelSettings = showExperimentalFeatures;
  static const bool showAutoGlm = showExperimentalFeatures;
}
