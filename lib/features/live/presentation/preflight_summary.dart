import '../domain/preflight_result.dart';

class PreflightSummary {
  const PreflightSummary({
    required this.readyAudioCount,
    required this.totalMomentCount,
    required this.warningCount,
    required this.errorCount,
  });

  final int readyAudioCount;
  final int totalMomentCount;
  final int warningCount;
  final int errorCount;

  @override
  bool operator ==(Object other) {
    return other is PreflightSummary &&
        readyAudioCount == other.readyAudioCount &&
        totalMomentCount == other.totalMomentCount &&
        warningCount == other.warningCount &&
        errorCount == other.errorCount;
  }

  @override
  int get hashCode =>
      Object.hash(readyAudioCount, totalMomentCount, warningCount, errorCount);
}

PreflightSummary summarizePreflight(
  PreflightResult result,
  int totalMomentCount,
) {
  return PreflightSummary(
    readyAudioCount: result.readyMomentIds.length,
    totalMomentCount: totalMomentCount,
    warningCount: result.items
        .where((item) => item.severity == PreflightSeverity.warning)
        .length,
    errorCount: result.items
        .where((item) => item.severity == PreflightSeverity.error)
        .length,
  );
}
