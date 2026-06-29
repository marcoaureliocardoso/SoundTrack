import 'dart:async';

import '../../../platform/documents/document_gateway.dart';
import '../data/event_export_codec.dart';
import '../data/event_repository.dart';
import '../domain/audio_reference.dart';
import '../domain/soundtrack_event.dart';

enum EventTransferException implements Exception {
  unplayableAudio,
  eventNotFound,
  momentNotFound,
}

class EventTransferController {
  EventTransferController({
    required this.gateway,
    required this.codec,
    required this.repository,
    required this.newId,
    required this.clock,
  });

  final DocumentGateway gateway;
  final EventExportCodec codec;
  final EventRepository repository;
  final String Function() newId;
  final DateTime Function() clock;
  final Map<String, Future<void>> _relinkQueues = {};

  Future<bool> exportEvent(SoundTrackEvent event) {
    return gateway.createEventJson(
      suggestedName: _safeName(event.name),
      contents: codec.encode(event, clock()),
    );
  }

  Future<SoundTrackEvent?> importEvent() async {
    final contents = await gateway.openEventJson();
    if (contents == null) return null;
    final event = await codec.decode(
      contents,
      replacementId: newId(),
      canRead: gateway.canRead,
      probeAudio: gateway.probeAudio,
    );
    await repository.save(event);
    return event;
  }

  Future<AudioReference?> selectAudio() async {
    final picked = await gateway.pickAudio();
    if (picked == null) return null;
    final probe = await gateway.probeAudio(picked.uri);
    if (!probe.playable) throw EventTransferException.unplayableAudio;
    return AudioReference(
      uri: picked.uri,
      displayName: picked.displayName,
      pending: false,
      artist: probe.artist,
      duration: probe.duration,
    );
  }

  Future<SoundTrackEvent> relinkMoment(
    SoundTrackEvent event,
    String momentId,
  ) async {
    final picked = await gateway.pickAudio();
    if (picked == null) {
      final authoritative = await repository.findById(event.id);
      if (authoritative == null) throw EventTransferException.eventNotFound;
      return authoritative;
    }
    final probe = await gateway.probeAudio(picked.uri);
    if (!probe.playable) throw EventTransferException.unplayableAudio;
    return _enqueueRelink(event.id, () async {
      final authoritative = await repository.findById(event.id);
      if (authoritative == null) throw EventTransferException.eventNotFound;
      final index = authoritative.moments.indexWhere(
        (moment) => moment.id == momentId,
      );
      if (index < 0) throw EventTransferException.momentNotFound;
      final moment = authoritative.moments[index];
      final updated = authoritative.updateMoment(
        moment.copyWith(
          audio: AudioReference(
            uri: picked.uri,
            displayName: picked.displayName,
            pending: false,
            artist: probe.artist,
            duration: probe.duration,
          ),
        ),
      );
      await repository.save(updated);
      return updated;
    });
  }

  Future<T> _enqueueRelink<T>(String eventId, Future<T> Function() operation) {
    final result = Completer<T>();
    final previous = _relinkQueues[eventId] ?? Future<void>.value();
    late final Future<void> tail;
    tail = previous.then<void>(
      (_) async {
        try {
          result.complete(await operation());
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        }
      },
      onError: (_) async {
        try {
          result.complete(await operation());
        } catch (error, stackTrace) {
          result.completeError(error, stackTrace);
        }
      },
    );
    _relinkQueues[eventId] = tail;
    tail.whenComplete(() {
      if (identical(_relinkQueues[eventId], tail)) {
        _relinkQueues.remove(eventId);
      }
    });
    return result.future;
  }

  static String _safeName(String name) {
    var stem = name
        .trim()
        .replaceFirst(RegExp(r'\.soundtrack\.json$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
    if (stem.length > 80) stem = stem.substring(0, 80);
    return '${stem.isEmpty ? 'evento' : stem}.soundtrack.json';
  }
}
