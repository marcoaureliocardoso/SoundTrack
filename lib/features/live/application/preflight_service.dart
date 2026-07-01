import '../../events/domain/soundtrack_event.dart';
import '../../../platform/system/system_status_gateway.dart';
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
  });

  final AudioPreflightProbe canRead;
  final AudioPreflightProbe canPrepare;
  final SystemStatusGateway systemStatus;
  final PreflightRecordRepository records;
  final DateTime Function() clock;

  Future<PreflightResult> check(SoundTrackEvent event) async {
    final items = <PreflightItem>[];
    final readyMomentIds = <String>{};

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

      bool readable;
      try {
        readable = await canRead(uri);
      } catch (error) {
        items.add(
          PreflightItem(
            code: PreflightCode.audioUnreadable,
            severity: PreflightSeverity.error,
            message:
                'Não foi possível verificar o áudio de “${moment.name}”: $error',
            momentId: moment.id,
          ),
        );
        continue;
      }
      if (!readable) {
        items.add(
          PreflightItem(
            code: PreflightCode.audioUnreadable,
            severity: PreflightSeverity.error,
            message: 'O áudio de “${moment.name}” não pode ser lido.',
            momentId: moment.id,
          ),
        );
        continue;
      }

      bool preparable;
      try {
        preparable = await canPrepare(uri);
      } catch (error) {
        items.add(
          PreflightItem(
            code: PreflightCode.audioUnpreparable,
            severity: PreflightSeverity.error,
            message: 'Não foi possível preparar “${moment.name}”: $error',
            momentId: moment.id,
          ),
        );
        continue;
      }
      if (!preparable) {
        items.add(
          PreflightItem(
            code: PreflightCode.audioUnpreparable,
            severity: PreflightSeverity.error,
            message: 'O áudio de “${moment.name}” não pode ser preparado.',
            momentId: moment.id,
          ),
        );
        continue;
      }
      readyMomentIds.add(moment.id);
    }

    await _checkSystem(items);

    final result = PreflightResult(
      items: items,
      readyMomentIds: readyMomentIds,
    );
    await records.save(
      PreflightRecord(
        eventId: event.id,
        checkedAt: clock(),
        eventUpdatedAt: event.updatedAt,
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

  Future<void> _checkSystem(List<PreflightItem> items) async {
    try {
      if (await systemStatus.mediaVolume() < .30) {
        items.add(
          const PreflightItem(
            code: PreflightCode.lowSystemVolume,
            severity: PreflightSeverity.warning,
            message: 'O volume de mídia do sistema está abaixo de 30%.',
          ),
        );
      }
    } catch (error) {
      items.add(
        PreflightItem(
          code: PreflightCode.lowSystemVolume,
          severity: PreflightSeverity.warning,
          message: 'Não foi possível verificar o volume do sistema: $error',
        ),
      );
    }

    try {
      final battery = await systemStatus.batteryPercent();
      final charging = await systemStatus.charging();
      if (battery < 20 && !charging) {
        items.add(
          PreflightItem(
            code: PreflightCode.lowBattery,
            severity: PreflightSeverity.warning,
            message: 'Bateria em $battery% e fora do carregador.',
          ),
        );
      }
    } catch (error) {
      items.add(
        PreflightItem(
          code: PreflightCode.lowBattery,
          severity: PreflightSeverity.warning,
          message: 'Não foi possível verificar a bateria: $error',
        ),
      );
    }

    try {
      final route = await systemStatus.outputRouteLabel();
      items.add(
        PreflightItem(
          code: PreflightCode.outputRoute,
          severity: PreflightSeverity.info,
          message: 'Saída de áudio: $route.',
        ),
      );
    } catch (error) {
      items.add(
        PreflightItem(
          code: PreflightCode.outputRoute,
          severity: PreflightSeverity.warning,
          message: 'Não foi possível confirmar a saída de áudio: $error',
        ),
      );
    }

    try {
      final enabled = await systemStatus.doNotDisturbEnabled();
      if (enabled != true) {
        items.add(
          PreflightItem(
            code: PreflightCode.doNotDisturb,
            severity: PreflightSeverity.warning,
            message: enabled == false
                ? 'Ative o Não Perturbe antes do evento.'
                : 'Não foi possível confirmar se o Não Perturbe está ativo.',
          ),
        );
      }
    } catch (error) {
      items.add(
        PreflightItem(
          code: PreflightCode.doNotDisturb,
          severity: PreflightSeverity.warning,
          message: 'Não foi possível verificar o Não Perturbe: $error',
        ),
      );
    }
  }
}
