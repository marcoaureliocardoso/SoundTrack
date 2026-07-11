import 'dart:math';

double effectiveVolume({
  required double master,
  required double modeVolume,
  required double gainDb,
}) {
  if (!master.isFinite || !modeVolume.isFinite || !gainDb.isFinite) {
    return 0;
  }
  final linearGain = pow(10, gainDb / 20).toDouble();
  return (master * modeVolume * linearGain).clamp(0.0, 1.0).toDouble();
}
