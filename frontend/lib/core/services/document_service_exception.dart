/// Exception specific to document service operations.
class DocumentServiceException implements Exception {
  final String message;
  final Exception? originalException;

  const DocumentServiceException(this.message, {this.originalException});

  @override
  String toString() => message;
}

/// User-facing message for document download/API failures.
String formatDocumentServiceError(Object error) {
  if (error is DocumentServiceException) {
    return error.message;
  }
  return error.toString();
}
