import 'package:flutter/services.dart';

import 'document_gateway.dart';

class MethodChannelDocumentGateway implements DocumentGateway {
  const MethodChannelDocumentGateway();

  static const MethodChannel _channel = MethodChannel(
    'com.soundtrack/documents',
  );
  static const Set<String> _cancellationCodes = {'cancelled', 'canceled'};

  @override
  Future<PickedDocument?> pickAudio() async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'pickAudio',
      );
      if (value == null) {
        return null;
      }
      return PickedDocument(
        uri: value['uri']! as String,
        displayName: value['displayName']! as String,
        mimeType: value['mimeType'] as String?,
        size: (value['size'] as num?)?.toInt(),
      );
    } on PlatformException catch (error) {
      if (_isCancellation(error)) {
        return null;
      }
      throw _typed(error);
    }
  }

  @override
  Future<String?> openEventJson() async {
    try {
      return await _channel.invokeMethod<String>('openEventJson');
    } on PlatformException catch (error) {
      if (_isCancellation(error)) {
        return null;
      }
      throw _typed(error);
    }
  }

  @override
  Future<bool> createEventJson({
    required String suggestedName,
    required String contents,
  }) async {
    try {
      return await _channel.invokeMethod<bool>('createEventJson', {
            'suggestedName': suggestedName,
            'contents': contents,
          }) ??
          false;
    } on PlatformException catch (error) {
      if (_isCancellation(error)) {
        return false;
      }
      throw _typed(error);
    }
  }

  @override
  Future<bool> canRead(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('canRead', {'uri': uri}) ??
          false;
    } on PlatformException catch (error) {
      throw _typed(error);
    }
  }

  @override
  Future<AudioProbeResult> probeAudio(String uri) async {
    try {
      final value = await _channel.invokeMapMethod<Object?, Object?>(
        'probeAudio',
        {'uri': uri},
      );
      if (value == null) {
        return const AudioProbeResult(playable: false);
      }
      final durationMs = (value['durationMs'] as num?)?.toInt();
      return AudioProbeResult(
        playable: value['playable'] as bool? ?? false,
        artist: value['artist'] as String?,
        duration: durationMs == null
            ? null
            : Duration(milliseconds: durationMs),
      );
    } on PlatformException catch (error) {
      throw _typed(error);
    }
  }

  static bool _isCancellation(PlatformException error) {
    return _cancellationCodes.contains(error.code);
  }

  static DocumentGatewayException _typed(PlatformException error) {
    return DocumentGatewayException(error.code, error.message);
  }
}
