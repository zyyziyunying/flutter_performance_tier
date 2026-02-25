import 'tier_config.dart';

abstract interface class ConfigProvider {
  Future<TierConfig> load();
}

class DefaultConfigProvider implements ConfigProvider {
  const DefaultConfigProvider({
    this.config = const TierConfig(),
    this.configOverride = const TierConfigOverride(),
  });

  final TierConfig config;
  final TierConfigOverride configOverride;

  @override
  Future<TierConfig> load() async => config.applyOverride(configOverride);
}
