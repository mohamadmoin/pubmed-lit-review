import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import '../../../core/models/document_model.dart';
import '../../../core/services/document_service.dart';
import 'document_file_save.dart';

String _downloadFilename(AIGeneratedDocument document) {
  final fromPath = p.basename(document.filePath.replaceAll('\\', '/'));
  if (fromPath.toLowerCase().endsWith('.docx') && fromPath.isNotEmpty) {
    return fromPath;
  }
  return 'document_${document.id}.docx';
}

Future<void> downloadGeneratedDocument(
  BuildContext context,
  AIGeneratedDocument document,
) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Preparing Word document download...')),
  );

  try {
    final bytes = await DocumentService().downloadDocument(document.id);
    final filename = _downloadFilename(document);
    final data = Uint8List.fromList(bytes);

    String? pickedPath;
    if (!kIsWeb) {
      try {
        pickedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Word Document',
          fileName: filename,
          type: FileType.custom,
          allowedExtensions: const ['docx'],
        );
      } catch (_) {
        pickedPath = null;
      }
    }

    final savedPath = await saveDocumentBytes(
      filename: filename,
      data: data,
      pickedPath: pickedPath,
    );

    if (!context.mounted) {
      return;
    }

    final statusText = kIsWeb
        ? 'Download started: $savedPath'
        : 'Document saved: $savedPath';

    final openAction = canOpenSavedFile
        ? SnackBarAction(
            label: 'Open',
            onPressed: () => OpenFile.open(savedPath),
          )
        : null;

    messenger.showSnackBar(
      SnackBar(
        content: Text(statusText),
        duration: const Duration(seconds: 6),
        action: openAction,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Document download failed: $error\n$stackTrace');
    if (!context.mounted) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('Download failed: ${formatDocumentServiceError(error)}'),
      ),
    );
  }
}
