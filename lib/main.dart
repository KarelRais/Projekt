import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'bluetooth_service.dart';
import 'filesystem_service.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDOPED',
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
  FileSystemService fs1 = FileSystemService();
  String filePath = '';

  void fileOpen(QuillController controller) async {
    final dir = await getApplicationDocumentsDirectory();
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: dir.path,
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    if (result == null) return;
    filePath = result.files.single.name;
    final content = await fs1.openFile(filePath);
    if (content == null) return;
    if (filePath.endsWith('.json')) {
      final delta = jsonDecode(content);
      controller.document = Document.fromJson(delta);
    } else {
      controller.document = Document()..insert(0, content);
    }
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
  }

  void fileSave(BuildContext context, QuillController controller) async {
    if (filePath == '') {
      fileSaveAs(context, controller);
    }
    if (filePath.endsWith('.json')) {
      await fs1.saveFormatted(filePath, controller);
    } else {
      await fs1.savePlain(filePath, controller);
    }
  }

  void fileSaveAs(BuildContext context, QuillController controller) async {
    final nameController = TextEditingController();
    filePath = (await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Uložit jako...'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              hintText: 'pro ukládání formátovaného textu použij příponu .json',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Storno'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, nameController.text.trim());
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    ))!;
    if (filePath == '') {
      return;
    }
    if (filePath.endsWith('.json')) {
      await fs1.saveFormatted(filePath, controller);
    } else {
      await fs1.savePlain(filePath, controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    String storedString = '';
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
              switch (value) {
                case 'open':
                  fileOpen(_controller);
                  break;
                case 'save':
                  fileSave(context, _controller);
                  break;
                case 'save_as':
                  fileSaveAs(context, _controller);
                  break;
                case 'close':
                  SystemNavigator.pop();
                  break;
                case 'bt_out':
                  fileBtOut();
                  break;
                case 'bt_in':
                  fileBtIn();
                  break;
              }
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
              switch (value) {
                case 'lang':
                  codeLang();
                  break;
                case 'begin':
                  codeBegin();
                  break;
                case 'end':
                  codeEnd();
                  break;
              }
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
                  funcReplace();
                  break;
                case 'remove':
                  funcRemove();
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
                  funcMath();
                  break;
                case 'hash':
                  funcHash();
                  break;
              }
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
              switch (value) {
                case 'encrypt':
                  securityEncrypt();
                  break;
                case 'decrypt':
                  securityDecrypt();
                  break;
                case 'hash':
                  securityHash();
                  break;
              }
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
              switch (value) {
                case 'help':
                  infoHelp();
                  break;
                case 'about':
                  infoAbout();
                  break;
                case 'license':
                  infoLicense();
                  break;
              }
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
