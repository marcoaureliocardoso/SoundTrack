enum PlaybackAlertCode {
  sourceUnavailable,
  sourceFailed,
  routeChanged,
  interruptionStarted,
  interruptionEnded,
}

class PlaybackAlert {
  const PlaybackAlert(this.code, this.message, {this.momentId});

  final PlaybackAlertCode code;
  final String message;
  final String? momentId;
}
