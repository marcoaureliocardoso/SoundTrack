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

  String get outputRouteLabel {
    const prefix = 'Saída de áudio: ';
    for (final item in items) {
      if (item.code != PreflightCode.outputRoute) continue;
      final message = item.message;
      if (message.startsWith(prefix) && message.endsWith('.')) {
        return message.substring(prefix.length, message.length - 1);
      }
    }
    return 'Saída não confirmada';
  }
}
