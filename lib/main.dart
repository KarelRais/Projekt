import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'bluetooth_service.dart';
import 'filesystem_service.dart';
import 'package:intl/intl.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDOPED',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent)),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      home: const MyHomePage(title: 'ANDOPED'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BluetoothService bt1 = BluetoothService();
  FileSystemService fs1 = FileSystemService();
  TextEditingController tec1 = TextEditingController();
  TextEditingController tec2 = TextEditingController();
  TextEditingController tec3 = TextEditingController();
  TextEditingController tec4 = TextEditingController();
  TextEditingController tec5 = TextEditingController();
  TextEditingController tec6 = TextEditingController();
  TextEditingController tec7 = TextEditingController();
  TextEditingController tec8 = TextEditingController();
  String filePath = '';
  bool _isJsonDocument = false;
  String _fileName = 'dokument.txt';
  int lang = 0;
  late QuillController _controller;
  late FocusNode _focusNode;
  late ScrollController _scrollController;

  static const MethodChannel _safChannel = MethodChannel('andoped/saf');

  String _basenameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx == -1 ? normalized : normalized.substring(idx + 1);
  }

  bool _isSafUri(String pathOrUri) {
    final v = pathOrUri.toLowerCase();
    return v.startsWith('content://') || v.startsWith('/document/');
  }

  String _normalizeFilePathForIo(String path) {
    // `dart:io` File() can't write to SAF `content://` URIs, but it *can* write
    // to regular file paths. Some pickers return `file://...` URIs; convert
    // those to a real filesystem path before writing.
    if (path.toLowerCase().startsWith('file://')) {
      return Uri.parse(path).toFilePath(windows: Platform.isWindows);
    }
    return path;
  }

  Future<void> _persistSafUriIfPossible(String uri) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_isSafUri(uri)) return;
    try {
      await _safChannel.invokeMethod('persistUri', {'uri': uri});
    } catch (_) {
      // Non-fatal: some providers don't support persistable permissions.
    }
  }

  Future<String> _readTextFromSafUri(String uri) async {
    final text = await _safChannel.invokeMethod<String>('readText', {'uri': uri});
    if (text == null) {
      throw Exception('Failed to read from $uri');
    }
    return text;
  }

  Future<void> _writeBytesToSafUri(String uri, Uint8List bytes) async {
    await _safChannel.invokeMethod('writeBytes', {'uri': uri, 'bytes': bytes});
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
    _controller = QuillController(
      document: Document.fromJson([{"insert": "\n"}]),
      selection: const TextSelection.collapsed(offset: 0),
    );
    // On Android, immediate autofocus runs before QuillRawEditor attaches its
    // input connection; a short delay matches focus to a mounted editor (opening
    // any PopupMenuButton used to "fix" this by cycling focus).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void focusEditor() {
        if (mounted) _focusNode.requestFocus();
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        Future.delayed(const Duration(milliseconds: 300), focusEditor);
      } else {
        focusEditor();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void fileOpen() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null) return;
    final picked = result.files.single;
    final path = picked.path;
    final identifier = picked.identifier;
    final String content;
    final String openedPathOrUri;

    // On Android, prefer SAF `content://` identifier if available. `picked.path`
    // is frequently a temp/cache copy and writing back to it won't update the
    // original document.
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        identifier != null &&
        _isSafUri(identifier)) {
      openedPathOrUri = identifier;
      await _persistSafUriIfPossible(identifier);
      content = await _readTextFromSafUri(identifier);
    } else if (path != null) {
      openedPathOrUri = _normalizeFilePathForIo(path);
      content = await File(openedPathOrUri).readAsString();
    } else {
      return;
    }
    setState(() {
      filePath = openedPathOrUri;
      _fileName = picked.name;
      _isJsonDocument = picked.extension?.toLowerCase() == 'json';
      _controller = QuillController(
        document: _isJsonDocument
            ? Document.fromJson(jsonDecode(content))
            : (Document()..insert(0, content)),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  Future<void> fileSave(BuildContext context) async {
    try {
      if (filePath.isEmpty) {
        await fileSaveAs(context);
        return;
      }

      final lowerPath = filePath.toLowerCase();
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) &&
          _isSafUri(lowerPath)) {
        final String content = _isJsonDocument
            ? jsonEncode(_controller.document.toDelta().toJson())
            : _controller.document.toPlainText();
        final Uint8List bytes = Uint8List.fromList(utf8.encode(content));
        await _persistSafUriIfPossible(filePath);
        await _writeBytesToSafUri(filePath, bytes);
        return;
      }
      final normalizedPath = _normalizeFilePathForIo(filePath);
      if (normalizedPath != filePath) {
        filePath = normalizedPath;
      }
      final file = File(normalizedPath);
      if (_isJsonDocument) {
        await file.writeAsString(
          jsonEncode(_controller.document.toDelta().toJson()),
        );
      } else {
        await file.writeAsString(_controller.document.toPlainText());
      }
    } catch (e, st) {
      debugPrint('fileSave failed: $e\n$st');
      if (!context.mounted) return;
      // If a file is already opened/saved, don't force a "Save as..." dialog on
      // failure; the user expects overwrite. Show an error instead.
      if (filePath.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uložení selhalo: $e')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Uložení selhalo: $e'),
      ));
    }
  }

  Future<void> fileSaveAs(BuildContext context) async {
    try {
      final String content = _isJsonDocument
          ? jsonEncode(_controller.document.toDelta().toJson())
          : _controller.document.toPlainText();
      final Uint8List bytes = Uint8List.fromList(utf8.encode(content));

      final String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Uložit jako...',
        fileName: _fileName,
        bytes: bytes,
      );
      if (savedPath == null) return;
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          _isSafUri(savedPath)) {
        filePath = savedPath;
      } else {
        filePath = _normalizeFilePathForIo(savedPath);
      }
      await _persistSafUriIfPossible(filePath);
      _fileName = _basenameFromPath(filePath);
      _isJsonDocument = _fileName.toLowerCase().endsWith('.json');
    } catch (e, st) {
      debugPrint('fileSaveAs failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uložení selhalo: $e')),
      );
    }
  }

  Future<void> fileBtOut(BuildContext context) async {
    try {
      final jsonString = jsonEncode(_controller.document.toDelta().toJson());
      await bt1.sendStringBroadcast(jsonString);
    } catch (e, st) {
      debugPrint('fileBtOut failed: $e\n$st');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth selhalo: $e')),
      );
    }
  }

  Future<void> fileBtIn() async {
    String str = '';
    await for (String str1 in bt1.onStringReceived()) {
      str += str1;
    }
    setState(() {
      _controller = QuillController(
        document: Document.fromJson(jsonDecode(str)),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void codeLang(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jazyk kódu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              /*TextButton(onPressed: () { langNone(); Navigator.pop(ctx); }, child: Text('Normální text')),*/
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  void codeBegin() {
    String code = '';
    switch (lang) {
      case 0: break;
      case 1: code = 'BITS 64\r\nORG 0x0100\r\n'; break;
      case 2: code = '#!/bin/bash'; break;
      case 3: code = '#include <stdio.h>\r\n\r\nint main(void)\r\n{\r\n'; break;
      case 4: code = '#include <iostream>\r\n\r\nint main(int argc, char *argv[]) {\r\n'; break;
      case 5: code = 'using System;\r\n\r\npublic class Program\r\n{\r\n\tpublic static void Main()\r\n\t{\r\n'; break;
      case 6: code = '@echo off\r\n'; break;
      case 7: break;
      case 8: code = '<!DOCTYPE html>\r\n<html>\r\n<head>\r\n<meta charset="utf-8">\r\n<title>'; break;
      case 9: code = 'public class Main\r\n{\r\n\tpublic static void Main(String[] args)\r\n\t{\r\n'; break;
      case 10: break;
      case 11: break;
      case 12: code = '<?php\r\n\t'; break;
      case 13: break;
      case 14: code = '<?xml version="1.0"?>'; break;
    }
    final codeBody = _controller.document.toPlainText();
    setState(() {
      _controller = QuillController(
        document: Document()..insert(0, code + codeBody),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void codeEnd() {
    String code = '';
    switch (lang) {
      case 0: break;
      case 1: code = '\r\nret'; break;
      case 2: break;
      case 3: code = '\r\n\t}\r\n}'; break;
      case 4: code = '\r\n\t}\r\n}'; break;
      case 5: code = '\r\n\t}\r\n}'; break;
      case 6: break;
      case 7: break;
      case 8: code = '\r\n</body></html>'; break;
      case 9: code = '\r\n\t}\r\n}'; break;
      case 10: break;
      case 11: break;
      case 12: code = '\r\n?>'; break;
      case 13: break;
      case 14: break;
    }
    final codeBody = _controller.document.toPlainText();
    setState(() {
      _controller = QuillController(
        document: Document()..insert(0, codeBody + code),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void funcReplace(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nahradit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec1, autocorrect: false, decoration: const InputDecoration(labelText: 'Co')),
              TextField(controller: tec2, autocorrect: false, decoration: const InputDecoration(labelText: 'Čím')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
          /*TextButton(onPressed: () { replaceOK(tec1.text, tec2.text); Navigator.pop(ctx); }, child: const Text('OK')),*/
        ],
      ),
    );
  }

  void funcRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odstranit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec3, autocorrect: false, decoration: const InputDecoration(labelText: 'Text k odstranění')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
          /*TextButton(onPressed: () { removeOK(tec3.text); Navigator.pop(ctx); }, child: const Text('OK')),*/
        ],
      ),
    );
  }

  void funcLower() {
    final delta = _controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert((op.data as String).toLowerCase(), op.attributes);
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    setState(() {
      _controller = QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void funcUpper() {
    final delta = _controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert((op.data as String).toUpperCase(), op.attributes);
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    setState(() {
      _controller = QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void funcTrimStart() {
    final delta = _controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert((op.data as String).trimLeft(), op.attributes);
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    setState(() {
      _controller = QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void funcTrimEnd() {
    final delta = _controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert((op.data as String).trimRight(), op.attributes);
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    setState(() {
      _controller = QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      );
    });
  }

  void funcMath(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Matematické'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec4, autocorrect: false, decoration: const InputDecoration(labelText: 'A'), keyboardType: TextInputType.number),
              TextField(controller: tec5, autocorrect: false, decoration: const InputDecoration(labelText: 'B'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  void funcHash(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hashovací'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec6, autocorrect: false, decoration: const InputDecoration(labelText: 'Text k hashování')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  void securityEncrypt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Šifrování'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec7, obscureText: true, autocorrect: false, decoration: const InputDecoration(labelText: 'Heslo')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  void securityDecrypt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dešifrování'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: tec8, obscureText: true, autocorrect: false, decoration: const InputDecoration(labelText: 'Heslo')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  void securityHash(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hash dokumentu'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_open),
            onSelected: (value) async {
              switch (value) {
                case 'open':
                  fileOpen();
                  break;
                case 'save':
                  await fileSave(context);
                  break;
                case 'save_as':
                  await fileSaveAs(context);
                  break;
                case 'close':
                  SystemNavigator.pop();
                  break;
                case 'bt_out':
                  await fileBtOut(context);
                  break;
                case 'bt_in':
                  fileBtIn();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'open', child: Text('Otevřít')),
              PopupMenuItem(value: 'save', child: Text('Uložit')),
              PopupMenuItem(value: 'save_as', child: Text('Uložit jako...')),
              PopupMenuItem(value: 'close', child: Text('Ukončit aplikaci')),
              PopupMenuItem(value: 'bt_out', child: Text('Odeslat přes Bluetooth')),
              PopupMenuItem(value: 'bt_in', child: Text('Přijmout přes Bluetooth')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.code),
            onSelected: (value) {
              switch (value) {
                case 'lang':
                  codeLang(context);
                  break;
                case 'begin':
                  codeBegin();
                  break;
                case 'end':
                  codeEnd();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'lang', child: Text('Jazyk kódu')),
              PopupMenuItem(value: 'begin', child: Text('Začátek kódu')),
              PopupMenuItem(value: 'end', child: Text('Konec kódu')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.functions),
            onSelected: (value) {
              switch (value) {
                case 'date':
                  _controller.document.insert(
                    _controller.selection.baseOffset,
                    DateFormat('d. MMMM yyyy').format(DateTime.now()),
                  );
                  break;
                case 'time':
                  _controller.document.insert(
                    _controller.selection.baseOffset,
                    DateFormat('HH:mm').format(DateTime.now()),
                  );
                  break;
                case 'date_time':
                  _controller.document.insert(
                    _controller.selection.baseOffset,
                    DateFormat('d. MMMM yyyy HH:mm').format(DateTime.now()),
                  );
                  break;
                case 'replace':
                  funcReplace(context);
                  break;
                case 'remove':
                  funcRemove(context);
                  break;
                case 'lower':
                  funcLower();
                  break;
                case 'upper':
                  funcUpper();
                  break;
                case 'trim_start':
                  funcTrimStart();
                  break;
                case 'trim_end':
                  funcTrimEnd();
                  break;
                case 'math':
                  funcMath(context);
                  break;
                case 'hash':
                  funcHash(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'date', child: Text('Datum')),
              PopupMenuItem(value: 'time', child: Text('Čas')),
              PopupMenuItem(value: 'date_time', child: Text('Datum a čas')),
              PopupMenuItem(value: 'replace', child: Text('Nahradit')),
              PopupMenuItem(value: 'remove', child: Text('Odstranit')),
              PopupMenuItem(value: 'lower', child: Text('Na malá')),
              PopupMenuItem(value: 'upper', child: Text('Na velká')),
              PopupMenuItem(value: 'trim_start', child: Text('Odstranit počáteční mezery')),
              PopupMenuItem(value: 'trim_end', child: Text('Odstranit koncové mezery')),
              PopupMenuItem(value: 'math', child: Text('Matematické')),
              PopupMenuItem(value: 'hash', child: Text('Hashovací')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.security),
            onSelected: (value) {
              switch (value) {
                case 'encrypt':
                  securityEncrypt(context);
                  break;
                case 'decrypt':
                  securityDecrypt(context);
                  break;
                case 'hash':
                  securityHash(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'encrypt', child: Text('Šifrování')),
              PopupMenuItem(value: 'decrypt', child: Text('Dešifrování')),
              PopupMenuItem(value: 'hash', child: Text('Hash dokumentu')),
              PopupMenuItem(value: 'signature', child: Text('Digitální podpis')),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.help),
            onSelected: (value) {
              switch (value) {
                case 'help':
                  break;
                case 'about':
                  break;
                case 'license':
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'help', child: Text('Nápověda')),
              PopupMenuItem(value: 'about', child: Text('O aplikaci')),
              PopupMenuItem(value: 'license', child: Text('Licence')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          QuillSimpleToolbar(controller: _controller),
          Expanded(
            child: QuillEditor(
              controller: _controller,
              scrollController: _scrollController,
              focusNode: _focusNode,
              config: const QuillEditorConfig(
                padding: EdgeInsets.all(8),
                autoFocus: false,
                expands: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
