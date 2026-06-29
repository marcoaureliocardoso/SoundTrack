import 'soundtrack_event.dart';

enum EventIssueCode { emptyName, noMoments, missingAudio, pendingAudio }

class EventIssue {
  const EventIssue({required this.code, required this.message, this.momentId});

  final EventIssueCode code;
  final String message;
  final String? momentId;
}

List<EventIssue> validateEvent(SoundTrackEvent event) {
  final issues = <EventIssue>[];

  if (event.name.trim().isEmpty) {
    issues.add(
      const EventIssue(
        code: EventIssueCode.emptyName,
        message: 'Informe o nome do evento.',
      ),
    );
  }

  if (event.moments.isEmpty) {
    issues.add(
      const EventIssue(
        code: EventIssueCode.noMoments,
        message: 'Adicione pelo menos um momento.',
      ),
    );
  }

  for (final moment in event.moments) {
    if (moment.audio == null) {
      issues.add(
        EventIssue(
          code: EventIssueCode.missingAudio,
          message: '${moment.name}: escolha uma música.',
          momentId: moment.id,
        ),
      );
    } else if (moment.audio!.pending) {
      issues.add(
        EventIssue(
          code: EventIssueCode.pendingAudio,
          message: '${moment.name}: religue o áudio pendente.',
          momentId: moment.id,
        ),
      );
    }
  }

  return issues;
}
