import '../../../platform/system/system_status_gateway.dart';
import '../../events/domain/event_moment.dart';
import '../../events/domain/soundtrack_event.dart';
import '../domain/preflight_result.dart';
import 'preflight_record_repository.dart';

typedef AudioPreflightProbe = Future<bool> Function(String uri);

class PreflightService {
  PreflightService({
    required this.canRead,
    required this.canPrepare,
    required this.systemStatus,
    required this.records,
    this.clock = DateTime.now,
    this.timeout = const Duration(seconds: 5),
  }) : assert(timeout > Duration.zero);

  final AudioPreflightProbe canRead;
  final AudioPreflightProbe canPrepare;
  final SystemStatusGateway systemStatus;
  final PreflightRecordRepository records;
  final DateTime Function() clock;
  final Duration timeout;

  Future<PreflightResult> check(SoundTrackEvent event) async {
    final items = <PreflightItem>[];
    final readyMomentIds = <String>{};
    final momentsByUri = <String, List<EventMoment>>{};

    for (final moment in event.moments) {
      final audio = moment.audio;
      final uri = audio?.uri;
      if (audio == null || audio.pending || uri == null || uri.isEmpty) {
        items.add(
          PreflightItem(
            code: PreflightCode.audioPending,
            severity: PreflightSeverity.error,
            message: '“${moment.name}” está sem áudio pronto.',
            momentId: moment.id,
          ),
        );
        continue;
      }
      momentsByUri.putIfAbsent(uri, () => []).add(moment);
    }

    final sourceChecks = await Future.wait(
      momentsByUri.entries.map(
        (entry) async => MapEntry(entry.key, await _checkSource(entry.key)),
      ),
    );
    for (final entry in sourceChecks) {
      final source = entry.value;
      for (final moment in momentsByUri[entry.key]!) {
        _appendSourceItems(items, moment, source);
        if (source.read.succeeded && source.prepare.succeeded) {
          readyMomentIds.add(moment.id);
        }
      }
    }

    items.addAll(await _checkSystem());

    final result = PreflightResult(
      items: items,
      readyMomentIds: readyMomentIds,
    );
    await records.save(
      PreflightRecord(
        eventId: event.id,
        checkedAt: clock(),
        eventUpdatedAt: event.updatedAt,
        sourceSignature: preflightSourceSignature(event),
        errorCount: items
            .where((item) => item.severity == PreflightSeverity.error)
            .length,
        warningCount: items
            .where((item) => item.severity == PreflightSeverity.warning)
            .length,
      ),
    );
    return result;
  }

  Future<_SourceCheck> _checkSource(String uri) async {
    final read = _runProbe(canRead, uri);
    final prepare = _runProbe(canPrepare, uri);
    final results = await Future.wait([read, prepare]);
    return _SourceCheck(read: results[0], prepare: results[1]);
  }

  Future<_ProbeResult> _runProbe(
    AudioPreflightProbe probe,
    String uri,
  ) async {
    try {
      return _ProbeResult(value: await probe(uri).timeout(timeout));
    } catch (error) {
      return _ProbeResult(error: error);
    }
  }

  void _appendSourceItems(
    List<PreflightItem> items,
    EventMoment moment,
    _SourceCheck source,
  ) {
    if (!source.read.succeeded) {
      items.add(
        PreflightItem(
          code: PreflightCode.audioUnreadable,
          severity: PreflightSeverity.error,
          message: source.read.error == null
              ? 'O áudio de “${moment.name}” não pode ser lido.'
              : 'Não foi possível verificar o áudio de “${moment.name}”: '
                    '${source.read.error}',
          momentId: moment.id,
        ),
      );
    }
    if (!source.prepare.succeeded) {
      items.add(
        PreflightItem(
          code: PreflightCode.audioUnpreparable,
          severity: PreflightSeverity.error,
          message: source.prepare.error == null
              ? 'O áudio de “${moment.name}” não pode ser preparado.'
              : 'Não foi possível preparar “${moment.name}”: '
                    '${source.prepare.error}',
          momentId: moment.id,
        ),
      );
    }
  }

  Future<List<PreflightItem>> _checkSystem() async {
    final checks = await Future.wait<PreflightItem?>([
      _checkVolume(),
      _checkBattery(),
      _checkRoute(),
      _checkDoNotDisturb(),
    ]);
    return checks.whereType<PreflightItem>().toList();
  }

  Future<PreflightItem?> _checkVolume() async {
    try {
      if (await systemStatus.mediaVolume().timeout(timeout) < .30) {
        return const PreflightItem(
          code: PreflightCode.lowSystemVolume,
          severity: PreflightSeverity.warning,
          message: 'O volume de mídia do sistema está abaixo de 30%.',
        );
      }
      return null;
    } catch (error) {
      return PreflightItem(
        code: PreflightCode.lowSystemVolume,
        severity: PreflightSeverity.warning,
        message: 'Não foi possível verificar o volume do sistema: $error',
      );
    }
  }

  Future<PreflightItem?> _checkBattery() async {
    try {
      final batteryFuture = systemStatus.batteryPercent().timeout(timeout);
      final chargingFuture = systemStatus.charging().timeout(timeout);
      final values = await Future.wait<Object>([
        batteryFuture,
        chargingFuture,
      ]);
      final battery = values[0] as int;
      final charging = values[1] as bool;
      if (battery < 20 && !charging) {
        return PreflightItem(
          code: PreflightCode.lowBattery,
          severity: PreflightSeverity.warning,
          message: 'Bateria em $battery% e fora do carregador.',
        );
      }
      return null;
    } catch (error) {
      return PreflightItem(
        code: PreflightCode.lowBattery,
        severity: PreflightSeverity.warning,
        message: 'Não foi possível verificar a bateria: $error',
      );
    }
  }

  Future<PreflightItem> _checkRoute() async {
    try {
      final route = await systemStatus.outputRouteLabel().timeout(timeout);
      return PreflightItem(
        code: PreflightCode.outputRoute,
        severity: PreflightSeverity.info,
        message: 'Saída de áudio: $route.',
      );
    } catch (error) {
      return PreflightItem(
        code: PreflightCode.outputRoute,
        severity: PreflightSeverity.warning,
        message: 'Não foi possível confirmar a saída de áudio: $error',
      );
    }
  }

  Future<PreflightItem?> _checkDoNotDisturb() async {
    try {
      final enabled = await systemStatus
          .doNotDisturbEnabled()
          .timeout(timeout);
      if (enabled == true) return null;
      return PreflightItem(
        code: PreflightCode.doNotDisturb,
        severity: PreflightSeverity.warning,
        message: enabled == false
            ? 'Ative o Não Perturbe antes do evento.'
            : 'Não foi possível confirmar se o Não Perturbe está ativo.',
      );
    } catch (error) {
      return PreflightItem(
        code: PreflightCode.doNotDisturb,
        severity: PreflightSeverity.warning,
        message: 'Não foi possível verificar o Não Perturbe: $error',
      );
    }
  }
}

class _SourceCheck {
  const _SourceCheck({required this.read, required this.prepare});

  final _ProbeResult read;
  final _ProbeResult prepare;
}

class _ProbeResult {
  const _ProbeResult({this.value, this.error});

  final bool? value;
  final Object? error;

  bool get succeeded => value == true && error == null;
}
