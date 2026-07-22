import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Save document bytes on IO platforms (Windows, macOS, Linux, mobile).
Future<String> saveDocumentBytes({
  required String filename,
  required Uint8List data,
  String? pickedPath,
}) async {
  if (pickedPath != null && pickedPath.isNotEmpty) {
    final path = _ensureDocxExtension(pickedPath);
    await File(path).writeAsBytes(data, flush: true);
    return path;
  }

  Directory dir;
  try {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }

  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(data, flush: true);
  return file.path;
}

String _ensureDocxExtension(String path) {
  if (path.toLowerCase().endsWith('.docx')) return path;
  return '$path.docx';
}

bool get canOpenSavedFile => true;
