import 'dart:html' as html;
import 'dart:typed_data';

/// Save document bytes in the browser via download.
Future<String> saveDocumentBytes({
  required String filename,
  required Uint8List data,
  String? pickedPath,
}) async {
  final blob = html.Blob([data], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return filename;
}

bool get canOpenSavedFile => false;
