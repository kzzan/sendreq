/// Renders a normalized OpenAPI document as a human-readable Markdown API
/// reference. Implementations must not read workspace or runtime state.
abstract interface class OpenApiMarkdownDocumentationPort {
  String render(String normalizedOpenApiJson, {required String languageCode});
}

/// Writes one Collection API reference to a caller-selected directory.
abstract interface class MarkdownDocumentationFilePort {
  Future<MarkdownDocumentationFileResult> write(
    MarkdownDocumentationFileRequest request,
  );
}

class MarkdownDocumentationFileRequest {
  const MarkdownDocumentationFileRequest({
    required this.outputDirectory,
    required this.collectionName,
    required this.source,
  });

  final String outputDirectory;
  final String collectionName;
  final String source;
}

class MarkdownDocumentationFileResult {
  const MarkdownDocumentationFileResult({required this.fileName});

  /// Safe leaf name only. Full local paths must not enter user notices.
  final String fileName;
}
