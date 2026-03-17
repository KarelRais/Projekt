import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_quill/flutter_quill.dart';

class FileSystemService {
  Future<Directory> _getDir() async {
    return await getApplicationDocumentsDirectory();
  }

  Future<String?> openFile(String filename) async {
    final dir = await _getDir();
    final file = File('${dir.path}/$filename');

    if (!await file.exists()) {
      return null;
    }

    return await file.readAsString();
  }

  Future<void> saveFormatted(
    String filename,
    QuillController controller,
  ) async {
    final dir = await _getDir();
    final file = File('${dir.path}/$filename');

    final jsonString = jsonEncode(controller.document.toDelta().toJson());

    await file.writeAsString(jsonString);
  }

  Future<void> savePlain(String filename, QuillController controller) async {
    final dir = await _getDir();
    final file = File('${dir.path}/$filename');

    final plainText = controller.document.toPlainText();

    await file.writeAsString(plainText);
  }
}
