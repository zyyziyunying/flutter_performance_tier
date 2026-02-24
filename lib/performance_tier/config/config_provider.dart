import 'tier_config.dart';

abstract interface class ConfigProvider {
  Future<TierConfig> load();
}

class DefaultConfigProvider implements ConfigProvider {
  const DefaultConfigProvider({this.config = const TierConfig()});

  final TierConfig config;

  @override
  Future<TierConfig> load() async => config;
}
