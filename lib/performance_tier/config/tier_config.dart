import 'package:flutter/foundation.dart';

import '../model/tier_level.dart';

@immutable
class TierConfig {
  const TierConfig({
    this.lowRamMaxBytes = 3 * _bytesPerGb,
    this.midRamMaxBytes = 6 * _bytesPerGb,
    this.highRamMaxBytes = 10 * _bytesPerGb,
    this.highMediaPerformanceClass = 12,
    this.ultraMediaPerformanceClass = 13,
    this.minSdkForHighTier = 0,
    this.minSdkForUltraTier = 0,
    this.modelTierCaps = const <ModelTierCapRule>[],
  }) : assert(lowRamMaxBytes > 0),
       assert(lowRamMaxBytes <= midRamMaxBytes),
       assert(midRamMaxBytes <= highRamMaxBytes),
       assert(highMediaPerformanceClass <= ultraMediaPerformanceClass),
       assert(minSdkForHighTier >= 0),
       assert(minSdkForUltraTier >= minSdkForHighTier);

  static const int _bytesPerGb = 1024 * 1024 * 1024;

  final int lowRamMaxBytes;
  final int midRamMaxBytes;
  final int highRamMaxBytes;
  final int highMediaPerformanceClass;
  final int ultraMediaPerformanceClass;
  final int minSdkForHighTier;
  final int minSdkForUltraTier;
  final List<ModelTierCapRule> modelTierCaps;

  TierConfig copyWith({
    int? lowRamMaxBytes,
    int? midRamMaxBytes,
    int? highRamMaxBytes,
    int? highMediaPerformanceClass,
    int? ultraMediaPerformanceClass,
    int? minSdkForHighTier,
    int? minSdkForUltraTier,
    List<ModelTierCapRule>? modelTierCaps,
  }) {
    return TierConfig(
      lowRamMaxBytes: lowRamMaxBytes ?? this.lowRamMaxBytes,
      midRamMaxBytes: midRamMaxBytes ?? this.midRamMaxBytes,
      highRamMaxBytes: highRamMaxBytes ?? this.highRamMaxBytes,
      highMediaPerformanceClass:
          highMediaPerformanceClass ?? this.highMediaPerformanceClass,
      ultraMediaPerformanceClass:
          ultraMediaPerformanceClass ?? this.ultraMediaPerformanceClass,
      minSdkForHighTier: minSdkForHighTier ?? this.minSdkForHighTier,
      minSdkForUltraTier: minSdkForUltraTier ?? this.minSdkForUltraTier,
      modelTierCaps: modelTierCaps ?? this.modelTierCaps,
    );
  }

  TierConfig applyOverride(TierConfigOverride override) {
    if (override.isEmpty) {
      return this;
    }

    var mergedMinSdkForHighTier =
        override.minSdkForHighTier ?? minSdkForHighTier;
    var mergedMinSdkForUltraTier =
        override.minSdkForUltraTier ?? minSdkForUltraTier;
    if (mergedMinSdkForUltraTier < mergedMinSdkForHighTier) {
      if (override.minSdkForUltraTier == null) {
        mergedMinSdkForUltraTier = mergedMinSdkForHighTier;
      } else if (override.minSdkForHighTier == null) {
        mergedMinSdkForHighTier = mergedMinSdkForUltraTier;
      } else {
        mergedMinSdkForUltraTier = mergedMinSdkForHighTier;
      }
    }

    return TierConfig(
      lowRamMaxBytes: override.lowRamMaxBytes ?? lowRamMaxBytes,
      midRamMaxBytes: override.midRamMaxBytes ?? midRamMaxBytes,
      highRamMaxBytes: override.highRamMaxBytes ?? highRamMaxBytes,
      highMediaPerformanceClass:
          override.highMediaPerformanceClass ?? highMediaPerformanceClass,
      ultraMediaPerformanceClass:
          override.ultraMediaPerformanceClass ?? ultraMediaPerformanceClass,
      minSdkForHighTier: mergedMinSdkForHighTier,
      minSdkForUltraTier: mergedMinSdkForUltraTier,
      modelTierCaps: override.modelTierCaps ?? modelTierCaps,
    );
  }

  factory TierConfig.fromMap(
    Map<String, Object?> map, {
    TierConfig fallback = const TierConfig(),
  }) {
    final override = TierConfigOverride.fromMap(map);
    return fallback.applyOverride(override);
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'lowRamMaxBytes': lowRamMaxBytes,
      'midRamMaxBytes': midRamMaxBytes,
      'highRamMaxBytes': highRamMaxBytes,
      'highMediaPerformanceClass': highMediaPerformanceClass,
      'ultraMediaPerformanceClass': ultraMediaPerformanceClass,
      'minSdkForHighTier': minSdkForHighTier,
      'minSdkForUltraTier': minSdkForUltraTier,
      'modelTierCaps': modelTierCaps.map((rule) => rule.toMap()).toList(),
    };
  }
}

@immutable
class TierConfigOverride {
  const TierConfigOverride({
    this.lowRamMaxBytes,
    this.midRamMaxBytes,
    this.highRamMaxBytes,
    this.highMediaPerformanceClass,
    this.ultraMediaPerformanceClass,
    this.minSdkForHighTier,
    this.minSdkForUltraTier,
    this.modelTierCaps,
  });

  final int? lowRamMaxBytes;
  final int? midRamMaxBytes;
  final int? highRamMaxBytes;
  final int? highMediaPerformanceClass;
  final int? ultraMediaPerformanceClass;
  final int? minSdkForHighTier;
  final int? minSdkForUltraTier;
  final List<ModelTierCapRule>? modelTierCaps;

  bool get isEmpty {
    return lowRamMaxBytes == null &&
        midRamMaxBytes == null &&
        highRamMaxBytes == null &&
        highMediaPerformanceClass == null &&
        ultraMediaPerformanceClass == null &&
        minSdkForHighTier == null &&
        minSdkForUltraTier == null &&
        modelTierCaps == null;
  }

  factory TierConfigOverride.fromMap(Map<String, Object?> map) {
    return TierConfigOverride(
      lowRamMaxBytes: _asInt(map['lowRamMaxBytes']),
      midRamMaxBytes: _asInt(map['midRamMaxBytes']),
      highRamMaxBytes: _asInt(map['highRamMaxBytes']),
      highMediaPerformanceClass: _asInt(map['highMediaPerformanceClass']),
      ultraMediaPerformanceClass: _asInt(map['ultraMediaPerformanceClass']),
      minSdkForHighTier: _asInt(map['minSdkForHighTier']),
      minSdkForUltraTier: _asInt(map['minSdkForUltraTier']),
      modelTierCaps: _parseModelTierCaps(map['modelTierCaps']),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'lowRamMaxBytes': lowRamMaxBytes,
      'midRamMaxBytes': midRamMaxBytes,
      'highRamMaxBytes': highRamMaxBytes,
      'highMediaPerformanceClass': highMediaPerformanceClass,
      'ultraMediaPerformanceClass': ultraMediaPerformanceClass,
      'minSdkForHighTier': minSdkForHighTier,
      'minSdkForUltraTier': minSdkForUltraTier,
      'modelTierCaps': modelTierCaps?.map((rule) => rule.toMap()).toList(),
    };
  }
}

@immutable
class ModelTierCapRule {
  const ModelTierCapRule({
    required this.pattern,
    required this.maxTier,
    this.caseSensitive = false,
  }) : assert(pattern != '');

  final String pattern;
  final TierLevel maxTier;
  final bool caseSensitive;

  bool matches(String candidate) {
    if (caseSensitive) {
      return candidate.contains(pattern);
    }
    return candidate.toLowerCase().contains(pattern.toLowerCase());
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'pattern': pattern,
      'maxTier': maxTier.name,
      'caseSensitive': caseSensitive,
    };
  }

  factory ModelTierCapRule.fromMap(Map<String, Object?> map) {
    final parsed = tryParse(map);
    if (parsed != null) {
      return parsed;
    }
    throw const FormatException('Invalid model tier cap rule.');
  }

  static ModelTierCapRule? tryParse(Map<String, Object?> map) {
    final pattern = _asString(map['pattern']);
    final maxTier = _parseTierLevel(map['maxTier']);
    if (pattern == null || maxTier == null) {
      return null;
    }
    return ModelTierCapRule(
      pattern: pattern,
      maxTier: maxTier,
      caseSensitive: _asBool(map['caseSensitive']) ?? false,
    );
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }
  }
  return null;
}

String? _asString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

TierLevel? _parseTierLevel(Object? value) {
  if (value is TierLevel) {
    return value;
  }
  if (value is! String) {
    return null;
  }
  final normalized = value.replaceAll('_', '').toLowerCase();
  for (final tier in TierLevel.values) {
    if (tier.name.toLowerCase() == normalized) {
      return tier;
    }
  }
  return null;
}

List<ModelTierCapRule>? _parseModelTierCaps(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is! List<Object?>) {
    return null;
  }

  final parsed = <ModelTierCapRule>[];
  for (final item in value) {
    if (item is Map<Object?, Object?>) {
      final normalized = <String, Object?>{};
      for (final entry in item.entries) {
        final key = entry.key;
        if (key is String) {
          normalized[key] = entry.value;
        }
      }
      final rule = ModelTierCapRule.tryParse(normalized);
      if (rule != null) {
        parsed.add(rule);
      }
    }
  }
  return parsed;
}
