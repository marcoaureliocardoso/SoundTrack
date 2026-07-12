import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/platform/system/method_channel_system_status_gateway.dart';
import 'package:soundtrack/platform/system/system_status_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('br.com.marcocardoso.soundtrack/system_status');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelSystemStatusGateway gateway;
  late List<MethodCall> calls;

  setUp(() {
    gateway = const MethodChannelSystemStatusGateway();
    calls = <MethodCall>[];
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void respondWith(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return handler(call);
    });
  }

  test('mediaVolume normalizes current against max', () async {
    respondWith((_) async => <String, Object?>{'current': 3, 'max': 10});

    expect(await gateway.mediaVolume(), .3);
    expect(calls.single.method, 'mediaVolume');
    expect(calls.single.arguments, isNull);
  });

  test('mediaVolume returns zero for the fail-safe zero pair', () async {
    respondWith((_) async => <String, Object?>{'current': 0, 'max': 0});

    expect(await gateway.mediaVolume(), 0);
  });

  test('mediaVolume rejects invalid payload and out-of-range values', () async {
    for (final payload in <Object?>[
      null,
      <String, Object?>{'current': '3', 'max': 10},
      <String, Object?>{'current': -1, 'max': 10},
      <String, Object?>{'current': 0, 'max': -1},
      <String, Object?>{'current': 1, 'max': 0},
      <String, Object?>{'current': 11, 'max': 10},
    ]) {
      respondWith((_) async => payload);

      await expectLater(
        gateway.mediaVolume(),
        throwsA(
          isA<SystemStatusException>().having(
            (error) => error.code,
            'code',
            'invalid_payload',
          ),
        ),
      );
    }
  });

  test('battery maps percent and charging from native payload', () async {
    respondWith(
      (_) async => <String, Object?>{'percent': 76, 'charging': true},
    );

    expect(await gateway.batteryPercent(), 76);
    expect(await gateway.charging(), isTrue);
    expect(calls.map((call) => call.method), ['battery', 'battery']);
  });

  test('battery rejects unknown or out-of-range values', () async {
    for (final payload in <Object?>[
      <String, Object?>{'percent': null, 'charging': false},
      <String, Object?>{'percent': 101, 'charging': false},
      <String, Object?>{'percent': 50, 'charging': 'yes'},
    ]) {
      respondWith((_) async => payload);

      await expectLater(
        gateway.batteryPercent(),
        throwsA(isA<SystemStatusException>()),
      );
    }
  });

  test('outputRoute maps a non-empty human-readable label', () async {
    respondWith((_) async => 'Bluetooth');

    expect(await gateway.outputRouteLabel(), 'Bluetooth');
    expect(calls.single.method, 'outputRoute');
  });

  test('outputRoute rejects an empty label', () async {
    respondWith((_) async => '  ');

    await expectLater(
      gateway.outputRouteLabel(),
      throwsA(isA<SystemStatusException>()),
    );
  });

  test('doNotDisturb preserves unavailable null', () async {
    respondWith((_) async => null);

    expect(await gateway.doNotDisturbEnabled(), isNull);
    expect(calls.single.method, 'doNotDisturb');
  });

  test('doNotDisturb rejects a non-boolean value', () async {
    respondWith((_) async => 1);

    await expectLater(
      gateway.doNotDisturbEnabled(),
      throwsA(isA<SystemStatusException>()),
    );
  });

  test('setKeepScreenOn sends only the requested boolean', () async {
    respondWith((_) async => null);

    await gateway.setKeepScreenOn(true);
    await gateway.setKeepScreenOn(false);

    expect(calls.map((call) => call.method), [
      'setKeepScreenOn',
      'setKeepScreenOn',
    ]);
    expect(calls.map((call) => call.arguments), [
      <String, Object?>{'enabled': true},
      <String, Object?>{'enabled': false},
    ]);
  });

  test('PlatformException becomes typed SystemStatusException', () async {
    respondWith((_) async {
      throw PlatformException(code: 'status_unavailable', message: 'gone');
    });

    await expectLater(
      gateway.outputRouteLabel(),
      throwsA(
        isA<SystemStatusException>()
            .having((error) => error.code, 'code', 'status_unavailable')
            .having((error) => error.message, 'message', 'gone'),
      ),
    );
  });
}
