abstract interface class SystemStatusGateway {
  Future<double> mediaVolume();

  Future<int> batteryPercent();

  Future<bool> charging();

  Future<String> outputRouteLabel();

  Future<bool?> doNotDisturbEnabled();

  Future<void> setKeepScreenOn(bool enabled);
}
