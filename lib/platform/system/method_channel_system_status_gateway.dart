import 'package:flutter/services.dart';

import 'system_status_gateway.dart';

class MethodChannelSystemStatusGateway implements SystemStatusGateway {
  const MethodChannelSystemStatusGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.soundtrack/system_status',
  );

  @override
  Future<double> mediaVolume() async {
    final payload = await _invokeMap('mediaVolume');
    final current = payload['current'];
    final max = payload['max'];
    if (current is! int || max is! int || current < 0 || max < 0) {
      throw _invalidPayload('mediaVolume requires non-negative integer values');
    }
    if (current == 0 && max == 0) {
      return 0;
    }
    if (max == 0 || current > max) {
      throw _invalidPayload('mediaVolume current must not exceed max');
    }
    return (current / max).clamp(0, 1).toDouble();
  }

  @override
  Future<int> batteryPercent() async {
    final payload = await _battery();
    return payload.percent;
  }

  @override
  Future<bool> charging() async {
    final payload = await _battery();
    return payload.charging;
  }

  @override
  Future<String> outputRouteLabel() async {
    final value = await _invoke<Object?>('outputRoute');
    if (value is! String || value.trim().isEmpty) {
      throw _invalidPayload('outputRoute requires a non-empty string');
    }
    return value.trim();
  }

  @override
  Future<bool?> doNotDisturbEnabled() async {
    final value = await _invoke<Object?>('doNotDisturb');
    if (value != null && value is! bool) {
      throw _invalidPayload('doNotDisturb requires a boolean or null');
    }
    return value as bool?;
  }

  @override
  Future<void> setKeepScreenOn(bool enabled) async {
    await _invoke<void>('setKeepScreenOn', {'enabled': enabled});
  }

  Future<_BatteryStatus> _battery() async {
    final payload = await _invokeMap('battery');
    final percent = payload['percent'];
    final charging = payload['charging'];
    if (percent is! int || percent < 0 || percent > 100 || charging is! bool) {
      throw _invalidPayload(
        'battery requires percent from 0 to 100 and boolean charging',
      );
    }
    return _BatteryStatus(percent, charging);
  }

  Future<Map<Object?, Object?>> _invokeMap(String method) async {
    final value = await _invoke<Object?>(method);
    if (value is! Map<Object?, Object?>) {
      throw _invalidPayload('$method requires a map payload');
    }
    return value;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw SystemStatusException(error.code, error.message);
    } on MissingPluginException catch (error) {
      throw SystemStatusException('channel_unavailable', error.message);
    }
  }

  static SystemStatusException _invalidPayload(String message) {
    return SystemStatusException('invalid_payload', message);
  }
}

class _BatteryStatus {
  const _BatteryStatus(this.percent, this.charging);

  final int percent;
  final bool charging;
}
