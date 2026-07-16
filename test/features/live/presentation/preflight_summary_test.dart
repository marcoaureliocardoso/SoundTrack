import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/features/live/domain/preflight_result.dart';
import 'package:soundtrack/features/live/presentation/preflight_summary.dart';

void main() {
  test('summarizes ready audio, warnings and errors', () {
    final result = PreflightResult(
      items: const [
        PreflightItem(
          code: PreflightCode.lowBattery,
          severity: PreflightSeverity.warning,
          message: 'Bateria baixa.',
        ),
        PreflightItem(
          code: PreflightCode.audioPending,
          severity: PreflightSeverity.error,
          message: 'Áudio pendente.',
        ),
      ],
      readyMomentIds: const {'one', 'two'},
    );

    expect(
      summarizePreflight(result, 3),
      const PreflightSummary(
        readyAudioCount: 2,
        totalMomentCount: 3,
        warningCount: 1,
        errorCount: 1,
      ),
    );
  });
}
