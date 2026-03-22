import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANDOPED',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent)),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        FlutterQuillLocalizations.delegate,   // ← DŮLEŽITÉ
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
  String storedString = '';
  int lang = 0;
  late QuillController _controller;

  @override
  void initState() {
    super.initState();
    storedString = '';
    dynamic _savedDelta;
    if (storedString.trim().isEmpty) {
      _savedDelta = [{"insert": "\n"}];
    } else {
      _savedDelta = jsonDecode(storedString);
    }
    _controller = QuillController(
      document: Document.fromJson(_savedDelta),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void fileOpen(QuillController controller) async {
    final dir = await getApplicationDocumentsDirectory();
    final result = await FilePicker.platform.pickFiles(
      initialDirectory: dir.path,
      type: FileType.custom,
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
    else if (filePath.endsWith('.json')) {
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

  void fileBtOut(QuillController controller) {
    String jsonString = jsonEncode(controller.document.toDelta().toJson());
    bt1.sendStringBroadcast(jsonString);
  }

  Future<void> fileBtIn(QuillController controller) async {
    String str = '';
    await for(String str1 in bt1.onStringReceived()) {
      str += str1;
    }
    controller.document = Document.fromJson(jsonDecode(str));
  }

  void codeLang(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            /*TextButton(onPressed: langNone(), child: Text('Normální text')),
            TextButton(onPressed: langAssembly(), child: Text('Assembly')),
            TextButton(onPressed: langBash(), child: Text('Bash')),
            TextButton(onPressed: langC(), child: Text('C')),
            TextButton(onPressed: langCpp(), child: Text('C++')),
            TextButton(onPressed: langCs(), child: Text('C#')),
            TextButton(onPressed: langCmd(), child: Text('CMD')),
            TextButton(onPressed: langCss(), child: Text('CSS')),
            TextButton(onPressed: langHtml(), child: Text('HTML')),
            TextButton(onPressed: langJava(), child: Text('Java')),
            TextButton(onPressed: langJavaScript(), child: Text('JavaScript')),
            TextButton(onPressed: langMarkdown(), child: Text('Markdown')),
            TextButton(onPressed: langPhp(), child: Text('PHP')),
            TextButton(onPressed: langPython(), child: Text('Python')),
            TextButton(onPressed: langXml(), child: Text('XML'))*/
          ]
        )
      )
    );
  }

  void codeBegin(QuillController controller) {
    String code = '';
    switch(lang) {
      case 0:
        break;
      case 1:
        code = 'BITS 64\r\nORG 0x0100\r\n';
        break;
      case 2:
        code = '#!/bin/bash';
        break;
      case 3:
        code = '#include <stdio.h>\r\n\r\nint main(void)\r\n{\r\n';
        break;
      case 4:
        code = '#include <iostream>\r\n\r\nint main(int argc, char *argv[]) {\r\n';
        break;
      case 5:
        code = 'using System;\r\n\r\npublic class Program\r\n{\r\n\tpublic static void Main()\r\n\t{\r\n';
        break;
      case 6:
        code = '@echo off\r\n';
        break;
      case 7:
        break;
      case 8:
        code = '<!DOCTYPE html>\r\n<html>\r\n<head>\r\n<meta charset="utf-8">\r\n<title>';
        break;
      case 9:
        code = 'public class Main\r\n{\r\n\tpublic static void Main(String[] args)\r\n\t{\r\n';
        break;
      case 10:
        break;
      case 11:
        break;
      case 12:
        code = '<?php\r\n\t';
        break;
      case 13:
        break;
      case 14:
        code = '<?xml version="1.0"?>';
        break;
    }
    String codeBody = controller.document.toPlainText();
    controller.document = Document()..insert(0, code + codeBody);
  }

  void codeEnd(QuillController controller) {
    String code = '';
    switch(lang) {
      case 0:
        break;
      case 1:
        code = '\r\nret';
        break;
      case 2:
        break;
      case 3:
        code = '\r\n\t}\r\n}';
        break;
      case 4:
        code = '\r\n\t}\r\n}';
        break;
      case 5:
        code = '\r\n\t}\r\n}';
        break;
      case 6:
        break;
      case 7:
        break;
      case 8:
        code = '\r\n</body></html>';
        break;
      case 9:
        code = '\r\n\t}\r\n}';
        break;
      case 10:
        break;
      case 11:
        break;
      case 12:
        code = '\r\n?>';
        break;
      case 13:
        break;
      case 14:
        break;
    }
    String codeBody = controller.document.toPlainText();
    controller.document = Document()..insert(0, codeBody + code);
  }

  void funcReplace(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec1, autocorrect: false, decoration: InputDecoration(labelText: 'Co')),
            TextField(controller: tec2, autocorrect: false, decoration: InputDecoration(labelText: 'Čím')),
            /*TextButton(onPressed: replaceOK(tec1.text, tec2.text), child: Text('OK')),
            TextButton(onPressed: generalCancel(context), child: Text('Storno')),*/
          ]
        )
      )
    );
  }

  void funcRemove(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec3, autocorrect: false, decoration: InputDecoration(labelText: 'Text k odstranění')),
            /*TextButton(onPressed: removeOK(tec3.text), child: Text('OK')),
            TextButton(onPressed: generalCancel(context), child: Text('Storno')),*/
          ]
        )
      )
    );
  }

  void funcLower(QuillController controller) {
    final delta = controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert(
          (op.data as String).toLowerCase(),
          op.attributes,
        );
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    controller.document = Document.fromDelta(newDelta);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
  }

  void funcUpper(QuillController controller) {
    final delta = controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert(
          (op.data as String).toUpperCase(),
          op.attributes,
        );
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    controller.document = Document.fromDelta(newDelta);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
  }

  void funcTrimStart(QuillController controller) {
    final delta = controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert(
          (op.data as String).trimLeft(),
          op.attributes,
        );
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    controller.document = Document.fromDelta(newDelta);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
  }

  void funcTrimEnd(QuillController controller) {
    final delta = controller.document.toDelta();
    final newDelta = Delta();
    for (final op in delta.toList()) {
      if (op.data is String) {
        newDelta.insert(
          (op.data as String).trimRight(),
          op.attributes,
        );
      } else {
        newDelta.insert(op.data, op.attributes);
      }
    }
    controller.document = Document.fromDelta(newDelta);
    controller.updateSelection(
      const TextSelection.collapsed(offset: 0),
      ChangeSource.local,
    );
  }

  void funcMath(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec4, autocorrect: false, decoration: InputDecoration(labelText: 'A'), keyboardType: .number),
            TextField(controller: tec5, autocorrect: false, decoration: InputDecoration(labelText: 'B'), keyboardType: .number),
            /*TextButton(onPressed: mathPlus(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A+B')),
            TextButton(onPressed: mathMinus(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A–B')),
            TextButton(onPressed: mathTimes(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A×B')),
            TextButton(onPressed: mathDiv(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A÷B')),
            TextButton(onPressed: mathPow(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A^B')),
            TextButton(onPressed: mathRoot(double.parse(tec4.text), double.parse(tec5.text)), child: Text('A-tá odm. B')),
            TextButton(onPressed: mathLog(double.parse(tec4.text), double.parse(tec5.text)), child: Text('Log. B při zákl. A')),
            TextButton(onPressed: mathSin(double.parse(tec4.text)), child: Text('Sin(A)')),
            TextButton(onPressed: mathCos(double.parse(tec4.text)), child: Text('Cos(A)')),
            TextButton(onPressed: mathTan(double.parse(tec4.text)), child: Text('Tan(A)')),
            TextButton(onPressed: mathCot(double.parse(tec4.text)), child: Text('Cot(A)')),
            TextButton(onPressed: mathSec(double.parse(tec4.text)), child: Text('Sec(A)')),
            TextButton(onPressed: mathCsc(double.parse(tec4.text)), child: Text('Csc(A)')),
            TextButton(onPressed: mathAsin(double.parse(tec4.text)), child: Text('Asin(A)')),
            TextButton(onPressed: mathAcos(double.parse(tec4.text)), child: Text('Acos(A)')),
            TextButton(onPressed: mathAtan(double.parse(tec4.text)), child: Text('Atan(A)')),
            TextButton(onPressed: mathSinh(double.parse(tec4.text)), child: Text('Sinh(A)')),
            TextButton(onPressed: mathCosh(double.parse(tec4.text)), child: Text('Cosh(A)')),
            TextButton(onPressed: mathTanh(double.parse(tec4.text)), child: Text('Tanh(A)')),
            TextButton(onPressed: generalCancel(context), child: Text('Storno')),*/
          ]
        )
      )
    );
  }

  void funcHash(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec6, autocorrect: false, decoration: InputDecoration(labelText: 'Text k hashování')),
            /*TextButton(onPressed: hashMD2(tec6.text), child: Text('MD2')),
            TextButton(onPressed: hashMD4(tec6.text), child: Text('MD4')),
            TextButton(onPressed: hashMD5(tec6.text), child: Text('MD5')),
            TextButton(onPressed: hashSHA1(tec6.text), child: Text('SHA1')),
            TextButton(onPressed: hashSHA256(tec6.text), child: Text('SHA256')),
            TextButton(onPressed: hashSHA384(tec6.text), child: Text('SHA384')),
            TextButton(onPressed: hashSHA512(tec6.text), child: Text('SHA512')),
            TextButton(onPressed: hashTiger(tec6.text), child: Text('Tiger')),
            TextButton(onPressed: generalCancel(), child: Text('Storno')),*/
          ]
        )
      )
    );
  }

  void securityEncrypt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec7, obscureText: true, autocorrect: false, decoration: InputDecoration(labelText: 'Heslo')),
            /*TextButton(onPressed: encryptAES(tec7.text), child: Text('AES')),
            TextButton(onPressed: encryptTwofish(tec7.text), child: Text('Twofish')),
            TextButton(onPressed: encryptBlowfish(tec7.text), child: Text('Blowfish')),
            TextButton(onPressed: encryptCamellia(tec7.text), child: Text('Camellia')),
            TextButton(onPressed: encryptDES(tec7.text), child: Text('DES')),
            TextButton(onPressed: encrypt3DES(tec7.text), child: Text('3DES')),
            TextButton(onPressed: encryptCAST5(tec7.text), child: Text('CAST5')),
            TextButton(onPressed: generalCancel(), child: Text('Storno')), */
          ]
        )
      )
    );
  }

  void securityDecrypt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [
            TextField(controller: tec8, obscureText: true, autocorrect: false, decoration: InputDecoration(labelText: 'Heslo')),
            /*TextButton(onPressed: decryptAES(tec7.text), child: Text('AES')),
            TextButton(onPressed: decryptTwofish(tec7.text), child: Text('Twofish')),
            TextButton(onPressed: decryptBlowfish(tec7.text), child: Text('Blowfish')),
            TextButton(onPressed: decryptCamellia(tec7.text), child: Text('Camellia')),
            TextButton(onPressed: decryptDES(tec7.text), child: Text('DES')),
            TextButton(onPressed: decrypt3DES(tec7.text), child: Text('3DES')),
            TextButton(onPressed: decryptCAST5(tec7.text), child: Text('CAST5')),
            TextButton(onPressed: generalCancel(), child: Text('Storno')), */
          ]
        )
      )
    );
  }

  void securityHash(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ListView(
          children: [/*
            TextButton(onPressed: shashMD2(), child: Text('MD2')),
            TextButton(onPressed: shashMD4(), child: Text('MD4')),
            TextButton(onPressed: shashMD5(), child: Text('MD5')),
            TextButton(onPressed: shashSHA1(), child: Text('SHA1')),
            TextButton(onPressed: shashSHA256(), child: Text('SHA256')),
            TextButton(onPressed: shashSHA384(), child: Text('SHA384')),
            TextButton(onPressed: shashSHA512(), child: Text('SHA512')),
            TextButton(onPressed: shashTiger(), child: Text('Tiger')),
            TextButton(onPressed: generalCancel(), child: Text('Storno')),*/
          ]
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  fileBtOut(_controller);
                  break;
                case 'bt_in':
                  fileBtIn(_controller);
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
                  codeLang(context);
                  break;
                case 'begin':
                  codeBegin(_controller);
                  break;
                case 'end':
                  codeEnd(_controller);
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
                  funcReplace(context);
                  break;
                case 'remove':
                  funcRemove(context);
                  break;
                case 'lower':
                  funcLower(_controller);
                  break;
                case 'upper':
                  funcUpper(_controller);
                  break;
                case 'trim_start':
                  funcTrimStart(_controller);
                  break;
                case 'trim_end':
                  funcTrimEnd(_controller);
                  break;
                case 'math':
                  funcMath(context);
                  break;
                case 'hash':
                  funcHash(context);
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
                  //infoHelp();
                  break;
                case 'about':
                  //infoAbout();
                  break;
                case 'license':
                  //infoLicense();
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
            QuillSimpleToolbar(controller: _controller),
            Expanded(
              child: QuillEditor(
                controller: _controller,
                scrollController: ScrollController(),
                focusNode: FocusNode(),
                config: QuillEditorConfig(
                  padding: EdgeInsets.all(8),
                  autoFocus: true,
                  expands: true,
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
