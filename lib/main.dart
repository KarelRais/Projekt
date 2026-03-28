import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' show BluetoothDevice;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'bluetooth_service.dart';
import 'filesystem_service.dart';
import 'backend.dart';

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
  Backend be1 = Backend();
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
  StreamSubscription<DocChange>? _docChangeSub;
  Timer? _highlightDebounce;
  bool _isApplyingHighlight = false;

  static const MethodChannel _safChannel = MethodChannel('andoped/saf');

  void _applySyntaxHighlight({bool keepSelection = true}) {
    try {
      if (_isApplyingHighlight) return;
      _isApplyingHighlight = true;
      final text = _controller.document.toPlainText();
      final docLen = _controller.document.length;
      final maxFormatLen = (docLen - 1).clamp(0, docLen); // exclude terminal '\n'

      // Clear previous color highlighting (but keep other formatting).
      if (maxFormatLen > 0) {
        _controller.formatText(
          0,
          maxFormatLen,
          Attribute.clone(Attribute.color, null),
        );
      }

      if (lang != 0 && maxFormatLen > 0) {
        for (final t in be1.tokenize(text, lang)) {
          final color = t.color;
          if (color == null) continue;
          final start = t.start.clamp(0, maxFormatLen);
          final end = t.end.clamp(0, maxFormatLen);
          final length = end - start;
          if (length <= 0) continue;
          _controller.formatText(
            start,
            length,
            Attribute.clone(Attribute.color, color),
          );
        }
      }
    } catch (e, st) {
      debugPrint('applySyntaxHighlight failed: $e\n$st');
    } finally {
      _isApplyingHighlight = false;
    }
  }

  void _attachRealtimeHighlighting() {
    _docChangeSub?.cancel();
    _docChangeSub = _controller.changes.listen((_) {
      if (lang == 0) return;
      if (_isApplyingHighlight) return;
      _highlightDebounce?.cancel();
      _highlightDebounce = Timer(const Duration(milliseconds: 180), () {
        _applySyntaxHighlight();
      });
    });
  }

  void _setController(QuillController controller) {
    _controller.dispose();
    _controller = controller;
    _attachRealtimeHighlighting();
  }

  void _selectLanguageAndHighlight(BuildContext dialogContext, int newLang) {
    Navigator.pop(dialogContext);
    setState(() {
      lang = newLang;
    });
    Future.microtask(_applySyntaxHighlight);
  }

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
    _attachRealtimeHighlighting();
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
    _highlightDebounce?.cancel();
    _docChangeSub?.cancel();
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
      _setController(QuillController(
        document: _isJsonDocument
            ? Document.fromJson(jsonDecode(content))
            : (Document()..insert(0, content)),
        selection: const TextSelection.collapsed(offset: 0),
      ));
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
      await bt1.ensureEnabled();
      final devices = await bt1.getBondedDevices();
      if (devices.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Není spárované žádné Bluetooth zařízení.')),
        );
        return;
      }
      if (!context.mounted) return;
      final picked = await showDialog<BluetoothDevice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Odeslat na zařízení'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in devices)
                  ListTile(
                    title: Text(d.name?.isNotEmpty == true ? d.name! : d.address),
                    subtitle: d.name?.isNotEmpty == true ? Text(d.address) : null,
                    onTap: () => Navigator.pop(ctx, d),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
          ],
        ),
      );
      if (picked == null) return;
      final jsonString = jsonEncode(_controller.document.toDelta().toJson());
      await bt1.sendStringToAddress(picked.address, jsonString);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odesláno přes Bluetooth.')),
      );
    } catch (e, st) {
      debugPrint('fileBtOut failed: $e\n$st');
      if (!context.mounted) return;
      var msg = e.toString();
      if (msg.startsWith('Exception: ')) msg = msg.substring('Exception: '.length);
      if (msg.length > 180) msg = '${msg.substring(0, 180)}…';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bluetooth selhalo: $msg')),
      );
    }
  }

  Future<void> fileBtIn() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Čekám na příchozí Bluetooth spojení…'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final str = await bt1.receiveString();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      setState(() {
        _setController(QuillController(
          document: Document.fromJson(jsonDecode(str)),
          selection: const TextSelection.collapsed(offset: 0),
        ));
      });
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Příjem selhal: $e')),
      );
    }
  }

  void codeLang(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jazyk kódu'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 0);
                },
                child: const Text('Normální text'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 1);
                },
                child: const Text('Assembly'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 2);
                },
                child: const Text('Bash'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 3);
                },
                child: const Text('C'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 4);
                },
                child: const Text('C++'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 5);
                },
                child: const Text('C#'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 6);
                },
                child: const Text('CMD'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 7);
                },
                child: const Text('CSS'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 8);
                },
                child: const Text('HTML'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 9);
                },
                child: const Text('Java'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 10);
                },
                child: const Text('JavaScript'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 11);
                },
                child: const Text('Markdown'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 12);
                },
                child: const Text('PHP'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 13);
                },
                child: const Text('Python'),
              ),
              TextButton(
                onPressed: () {
                  _selectLanguageAndHighlight(ctx, 14);
                },
                child: const Text('XML'),
              ),
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
      _setController(QuillController(
        document: Document()..insert(0, code + codeBody),
        selection: const TextSelection.collapsed(offset: 0),
      ));
    });
    if (lang != 0) _applySyntaxHighlight(keepSelection: false);
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
      _setController(QuillController(
        document: Document()..insert(0, codeBody + code),
        selection: const TextSelection.collapsed(offset: 0),
      ));
    });
    if (lang != 0) _applySyntaxHighlight(keepSelection: false);
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
          TextButton(onPressed: () { be1.replace(tec1.text, tec2.text, _controller); }, child: const Text('OK')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
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
          TextButton(onPressed: () { be1.replace(tec3.text, '', _controller); }, child: const Text('OK')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
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
      _setController(QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      ));
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
      _setController(QuillController(
        document: Document.fromDelta(newDelta),
        selection: const TextSelection.collapsed(offset: 0),
      ));
    });
  }

  void funcTrimStart() {
    final content = _controller.document.toPlainText();
    final trimmed = content.replaceAllMapped(
      RegExp(r'(^|\n)[ \t]+'),
      (m) => m.group(1)!,
    );
    setState(() {
      _setController(QuillController(
        document: Document()..insert(0, trimmed),
        selection: const TextSelection.collapsed(offset: 0),
      ));
    });
  }

  void funcTrimEnd() {
    final content = _controller.document.toPlainText();
    final trimmed = content.replaceAll(RegExp(r'[ \t]+(?=\n|$)'), '');
    setState(() {
      _setController(QuillController(
        document: Document()..insert(0, trimmed),
        selection: const TextSelection.collapsed(offset: 0),
      ));
    });
  }

  void funcMath(BuildContext context) {
    double? parseInput(String value) => double.tryParse(value.replaceAll(',', '.'));

    void withA(
      BuildContext ctx,
      void Function(double a) action,
    ) {
      final a = parseInput(tec4.text);
      if (a == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neplatná hodnota A')),
        );
        return;
      }
      action(a);
      Navigator.pop(ctx);
    }

    void withAB(
      BuildContext ctx,
      void Function(double a, double b) action,
    ) {
      final a = parseInput(tec4.text);
      final b = parseInput(tec5.text);
      if (a == null || b == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Neplatná hodnota A nebo B')),
        );
        return;
      }
      action(a, b);
      Navigator.pop(ctx);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final viewH = mq.size.height - mq.viewInsets.bottom;
        // Dialog default insetPadding is 24 vertical on each side; leave headroom so the
        // scroll viewport never exceeds the overlay (avoids bottom overflow).
        final scrollViewportH = (viewH - 56).clamp(0.0, double.infinity);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Material(
            type: MaterialType.canvas,
            color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              height: scrollViewportH > 0 ? scrollViewportH : viewH * 0.5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Matematické', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tec4,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'A'),
                    ),
                    TextField(
                      controller: tec5,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'B'),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathPlus(a, b, _controller)), child: const Text('A+B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathMinus(a, b, _controller)), child: const Text('A-B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathMultiply(a, b, _controller)), child: const Text('A×B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathDivide(a, b, _controller)), child: const Text('A÷B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathPower(a, b, _controller)), child: const Text('A^B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathRoot(a, b, _controller)), child: const Text('A√B')),
                        TextButton(onPressed: () => withAB(ctx, (a, b) => be1.mathLog(a, b, _controller)), child: const Text('logA(B)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathSin(a, _controller)), child: const Text('sin(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathCos(a, _controller)), child: const Text('cos(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathTan(a, _controller)), child: const Text('tan(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathCot(a, _controller)), child: const Text('cot(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathSec(a, _controller)), child: const Text('sec(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathCsc(a, _controller)), child: const Text('csc(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathAsin(a, _controller)), child: const Text('asin(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathAcos(a, _controller)), child: const Text('acos(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathAtan(a, _controller)), child: const Text('atan(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathSinh(a, _controller)), child: const Text('sinh(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathCosh(a, _controller)), child: const Text('cosh(A)')),
                        TextButton(onPressed: () => withA(ctx, (a) => be1.mathTanh(a, _controller)), child: const Text('tanh(A)')),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
                      ],
                    ),
                  ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  void funcHash(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final viewH = mq.size.height - mq.viewInsets.bottom;
        final scrollViewportH = (viewH - 56).clamp(0.0, double.infinity);
        return Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Material(
            type: MaterialType.canvas,
            color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              height: scrollViewportH > 0 ? scrollViewportH : viewH * 0.5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Hashovací', style: Theme.of(ctx).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tec6,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Text k hashování'),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(onPressed: () { be1.hash_md2(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('MD2')),
                        TextButton(onPressed: () { be1.hash_md4(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('MD4')),
                        TextButton(onPressed: () { be1.hash_md5(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('MD5')),
                        TextButton(onPressed: () { be1.hash_sha1(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('SHA1')),
                        TextButton(onPressed: () { be1.hash_sha256(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('SHA256')),
                        TextButton(onPressed: () { be1.hash_sha384(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('SHA384')),
                        TextButton(onPressed: () { be1.hash_sha512(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('SHA512')),
                        TextButton(onPressed: () { be1.hash_ripemd160(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('RIPEMD160')),
                        TextButton(onPressed: () {   be1.hash_whirlpool(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('Whirlpool')),
                        TextButton(onPressed: () { be1.hash_tiger(tec6.text, _controller); Navigator.pop(ctx); }, child: const Text('Tiger')),
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Storno')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /*void securityEncrypt(BuildContext context) {
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
  }*/

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
          /*PopupMenuButton<String>(
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
          ),*/
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