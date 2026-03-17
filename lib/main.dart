import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'bluetooth_service.dart';
import 'filesystem_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.blueAccent)),
      debugShowCheckedModeBanner: false,
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
  @override
  Widget build(BuildContext context) {
    String storedString = "";
    final _savedDelta = jsonDecode(storedString);
    final _controller = QuillController(
      document: Document.fromJson(_savedDelta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    storedString = jsonEncode(_controller.document.toDelta().toJson());
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.file_open),
            onSelected: (value) {
              /// IF VALUE
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'open', child: Text('Otevřít')),
              PopupMenuItem(value: 'save', child: Text('Uložit')),
              PopupMenuItem(
                value: 'save_format',
                child: Text('Uložit jako...'),
              ),
              PopupMenuItem(
                value: 'save_no_format',
                child: Text('Uložit jako prostý text'),
              ),
              PopupMenuItem(value: 'close', child: Text('Ukončit aplikaci')),
              PopupMenuItem(
                value: 'bt_out',
                child: Text('Odeslat přes Bluetooth'),
              ),
              PopupMenuItem(
                value: 'bt_in',
                child: Text('Přijmout přes Bluetooth'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.code),
            onSelected: (value) {
              /// IF VALUE
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'lang', child: Text('Jazyk kódu')),
              PopupMenuItem(value: 'begin', child: Text('Začátek kódu')),
              PopupMenuItem(value: 'end', child: Text('Konec kódu')),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.functions),
            onSelected: (value) {
              /// IF VALUE
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'date', child: Text('Datum')),
              PopupMenuItem(value: 'time', child: Text('Čas')),
              PopupMenuItem(value: 'date_time', child: Text('Datum a čas')),
              PopupMenuItem(value: 'replace', child: Text('Nahradit')),
              PopupMenuItem(value: 'remove', child: Text('Odstranit')),
              PopupMenuItem(value: 'lower', child: Text('Na malá')),
              PopupMenuItem(value: 'upper', child: Text('Na velká')),
              PopupMenuItem(
                value: 'trim_start',
                child: Text('Odstranit počáteční mezery'),
              ),
              PopupMenuItem(
                value: 'trim_end',
                child: Text('Odstranit koncové mezery'),
              ),
              PopupMenuItem(value: 'math', child: Text('Matematické')),
              PopupMenuItem(value: 'hash', child: Text('Hashovací')),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.security),
            onSelected: (value) {
              /// IF VALUE
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'encrypt', child: Text('Šifrování')),
              PopupMenuItem(value: 'decrypt', child: Text('Dešifrování')),
              PopupMenuItem(value: 'hash', child: Text('Hash dokumentu')),
              PopupMenuItem(
                value: 'signature',
                child: Text('Digitální podpis'),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.help),
            onSelected: (value) {
              /// IF VALUE
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'help', child: Text('Nápověda')),
              PopupMenuItem(value: 'about', child: Text('O aplikaci')),
              PopupMenuItem(value: 'license', child: Text('Licence')),
            ],
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            QuillToolbar.basic(controller: _controller),
            Expanded(
              child: QuillEditor(
                controller: _controller,
                scrollController: ScrollController(),
                scrollable: true,
                focusNode: FocusNode(),
                autoFocus: true,
                readOnly: false,
                expands: true,
                padding: EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
