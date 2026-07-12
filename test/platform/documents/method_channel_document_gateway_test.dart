import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundtrack/platform/documents/document_gateway.dart';
import 'package:soundtrack/platform/documents/method_channel_document_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('br.com.marcocardoso.soundtrack/documents');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelDocumentGateway gateway;
  late List<MethodCall> calls;

  setUp(() {
    gateway = const MethodChannelDocumentGateway();
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

  test('pickAudio maps document metadata', () async {
    respondWith(
      (_) async => <String, Object?>{
        'uri': 'content://audio/42',
        'displayName': 'entrance.mp3',
        'mimeType': 'audio/mpeg',
        'size': 12345,
      },
    );

    final picked = await gateway.pickAudio();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'pickAudio');
    expect(calls.single.arguments, isNull);
    expect(
      picked,
      const PickedDocument(
        uri: 'content://audio/42',
        displayName: 'entrance.mp3',
        mimeType: 'audio/mpeg',
        size: 12345,
      ),
    );
  });

  test('openEventJson returns UTF-8 contents', () async {
    const json = '{"name":"Abertura","emoji":"🎵"}';
    respondWith((_) async => json);

    final contents = await gateway.openEventJson();

    expect(calls.single, isA<MethodCall>());
    expect(calls.single.method, 'openEventJson');
    expect(calls.single.arguments, isNull);
    expect(contents, json);
  });

  test('createEventJson sends suggested name and contents', () async {
    respondWith((_) async => true);

    final created = await gateway.createEventJson(
      suggestedName: 'casamento.json',
      contents: '{"title":"Casamento"}',
    );

    expect(created, isTrue);
    expect(calls.single.method, 'createEventJson');
    expect(calls.single.arguments, <String, Object?>{
      'suggestedName': 'casamento.json',
      'contents': '{"title":"Casamento"}',
    });
  });

  test('picker cancellation returns null or false', () async {
    respondWith((call) async {
      throw PlatformException(code: 'cancelled', message: call.method);
    });

    expect(await gateway.pickAudio(), isNull);
    expect(await gateway.openEventJson(), isNull);
    expect(
      await gateway.createEventJson(
        suggestedName: 'event.json',
        contents: '{}',
      ),
      isFalse,
    );
  });

  test('native null cancellation returns null or false', () async {
    respondWith((_) async => null);

    expect(await gateway.pickAudio(), isNull);
    expect(await gateway.openEventJson(), isNull);
    expect(
      await gateway.createEventJson(
        suggestedName: 'event.json',
        contents: '{}',
      ),
      isFalse,
    );
  });

  test('canRead maps uri argument and result', () async {
    respondWith((_) async => true);

    final readable = await gateway.canRead('content://audio/42');

    expect(readable, isTrue);
    expect(calls.single.method, 'canRead');
    expect(calls.single.arguments, <String, Object?>{
      'uri': 'content://audio/42',
    });
  });

  test('probeAudio maps uri and audio metadata', () async {
    respondWith(
      (_) async => <String, Object?>{
        'playable': true,
        'artist': 'Banda',
        'durationMs': 90500,
      },
    );

    final probe = await gateway.probeAudio('content://audio/42');

    expect(calls.single.method, 'probeAudio');
    expect(calls.single.arguments, <String, Object?>{
      'uri': 'content://audio/42',
    });
    expect(
      probe,
      const AudioProbeResult(
        playable: true,
        artist: 'Banda',
        duration: Duration(milliseconds: 90500),
      ),
    );
  });

  test('non-cancellation PlatformException becomes typed exception', () async {
    respondWith((_) async {
      throw PlatformException(code: 'read_failed', message: 'Unreadable');
    });

    await expectLater(
      gateway.openEventJson(),
      throwsA(
        isA<DocumentGatewayException>()
            .having((error) => error.code, 'code', 'read_failed')
            .having((error) => error.message, 'message', 'Unreadable'),
      ),
    );
  });
}
