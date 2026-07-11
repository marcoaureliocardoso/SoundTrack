abstract interface class SystemStatusGateway {
  Future<double> mediaVolume();

  Future<int> batteryPercent();

  Future<bool> charging();

  Future<String> outputRouteLabel();

  Future<bool?> doNotDisturbEnabled();

  Future<void> setKeepScreenOn(bool enabled);
}

class SystemStatusException implements Exception {
  const SystemStatusException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() {
    final description = message;
    return description == null
        ? 'SystemStatusException($code)'
        : 'SystemStatusException($code): $description';
  }
}
