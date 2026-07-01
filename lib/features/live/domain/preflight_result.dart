enum PreflightSeverity { info, warning, error }

enum PreflightCode {
  audioPending,
  audioUnreadable,
  audioUnpreparable,
  lowSystemVolume,
  lowBattery,
  outputRoute,
  doNotDisturb,
}

class PreflightItem {
  const PreflightItem({
    required this.code,
    required this.severity,
    required this.message,
    this.momentId,
  });

  final PreflightCode code;
  final PreflightSeverity severity;
  final String message;
  final String? momentId;
}

class PreflightResult {
  PreflightResult({
    required Iterable<PreflightItem> items,
    required Iterable<String> readyMomentIds,
  }) : items = List.unmodifiable(items),
       readyMomentIds = Set.unmodifiable(readyMomentIds);

  final List<PreflightItem> items;
  final Set<String> readyMomentIds;

  bool get hasErrors =>
      items.any((item) => item.severity == PreflightSeverity.error);

  bool get hasWarnings =>
      items.any((item) => item.severity == PreflightSeverity.warning);
}
