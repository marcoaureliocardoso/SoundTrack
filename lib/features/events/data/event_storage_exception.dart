enum EventStorageErrorCode { incompatibleSchema, corruptedData }

class EventStorageException implements Exception {
  const EventStorageException({
    required this.code,
    required this.path,
    required this.cause,
    this.stackTrace,
  });

  final EventStorageErrorCode code;
  final String path;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() {
    return 'EventStorageException($code, path: $path, cause: $cause)';
  }
}
