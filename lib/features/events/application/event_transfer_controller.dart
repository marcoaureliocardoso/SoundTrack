import '../../../platform/documents/document_gateway.dart';
import '../data/event_export_codec.dart';
import '../data/event_repository.dart';
import '../domain/audio_reference.dart';
import '../domain/soundtrack_event.dart';

enum EventTransferException implements Exception {
  unplayableAudio,
  momentNotFound,
}

class EventTransferController {
  const EventTransferController({
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
    final authoritative = await repository.findById(event.id) ?? event;
    final index = authoritative.moments.indexWhere(
      (moment) => moment.id == momentId,
    );
    if (index < 0) throw EventTransferException.momentNotFound;
    final picked = await gateway.pickAudio();
    if (picked == null) return authoritative;
    final probe = await gateway.probeAudio(picked.uri);
    if (!probe.playable) throw EventTransferException.unplayableAudio;
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
  }

  static String _safeName(String name) {
    final stem = name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9À-ÿ._-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
    return '${stem.isEmpty ? 'evento' : stem}.soundtrack.json';
  }
}
