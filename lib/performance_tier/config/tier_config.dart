class TierConfig {
  const TierConfig({
    this.lowRamMaxBytes = 3 * 1024 * 1024 * 1024,
    this.midRamMaxBytes = 6 * 1024 * 1024 * 1024,
    this.highRamMaxBytes = 10 * 1024 * 1024 * 1024,
    this.highMediaPerformanceClass = 12,
    this.ultraMediaPerformanceClass = 13,
  });

  final int lowRamMaxBytes;
  final int midRamMaxBytes;
  final int highRamMaxBytes;
  final int highMediaPerformanceClass;
  final int ultraMediaPerformanceClass;

  Map<String, Object> toMap() {
    return <String, Object>{
      'lowRamMaxBytes': lowRamMaxBytes,
      'midRamMaxBytes': midRamMaxBytes,
      'highRamMaxBytes': highRamMaxBytes,
      'highMediaPerformanceClass': highMediaPerformanceClass,
      'ultraMediaPerformanceClass': ultraMediaPerformanceClass,
    };
  }
}
