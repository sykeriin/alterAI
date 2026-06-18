/// Typed service failure — technical detail stays internal; UI uses [UserFacingError].
enum ServiceErrorKind {
  network,
  auth,
  quota,
  notConfigured,
  notFound,
  server,
  parse,
  permission,
  unknown,
}

class AlterServiceException implements Exception {
  const AlterServiceException(
    this.technicalMessage, {
    this.kind = ServiceErrorKind.unknown,
    this.statusCode,
  });

  final String technicalMessage;
  final ServiceErrorKind kind;
  final int? statusCode;

  @override
  String toString() => technicalMessage;
}
