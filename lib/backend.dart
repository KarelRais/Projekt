import 'dart:convert';
import 'dart:math' as math;

import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hashlib/hashlib.dart' as hl;
import 'package:pointycastle/api.dart' show Digest;
import 'package:pointycastle/digests/tiger.dart';
import 'package:pointycastle/digests/whirlpool.dart';

class Backend {
  static const _colors = {
    'keyword': '#1565C0',
    'string': '#2E7D32',
    'comment': '#616161',
    'number': '#EF6C00',
    'tag': '#6A1B9A',
  };

  String? colorForToken(String token, int lang) {
    final isMarkup = (lang == 8 || lang == 14);
    final lower = token.toLowerCase();
    final isNumber = RegExp(r'^\d').hasMatch(token);
    final isString = token.startsWith("'") || token.startsWith('"');
    final isComment = switch (lang) {
      2 => token.startsWith('#'),
      6 => lower.startsWith('rem'),
      13 => token.startsWith('#'),
      _ => token.startsWith('//') || token.startsWith('/*'),
    };
    final isTag = isMarkup && (token.startsWith('<') || token.startsWith('</'));

    if (isComment) return _colors['comment'];
    if (isString) return _colors['string'];
    if (isNumber) return _colors['number'];
    if (isTag) return _colors['tag'];
    if (_keywordsFor(lang).contains(token)) return _colors['keyword'];
    return null;
  }

  Set<String> _keywordsFor(int lang) {
    switch (lang) {
      case 2: // Bash
        return {
          'if',
          'then',
          'elif',
          'else',
          'fi',
          'for',
          'while',
          'do',
          'done',
          'case',
          'esac',
          'in',
          'function',
          'return',
          'exit',
        };
      case 3: // C
      case 4: // C++
        return {
          'auto',
          'break',
          'case',
          'char',
          'class',
          'const',
          'continue',
          'default',
          'do',
          'double',
          'else',
          'enum',
          'extern',
          'float',
          'for',
          'goto',
          'if',
          'inline',
          'int',
          'long',
          'namespace',
          'operator',
          'private',
          'protected',
          'public',
          'register',
          'return',
          'short',
          'signed',
          'sizeof',
          'static',
          'struct',
          'switch',
          'template',
          'this',
          'typedef',
          'typename',
          'union',
          'unsigned',
          'using',
          'virtual',
          'void',
          'volatile',
          'while',
          'new',
          'delete',
          'nullptr',
          'true',
          'false',
          'try',
          'catch',
          'throw',
        };
      case 5: // C#
        return {
          'using',
          'namespace',
          'class',
          'struct',
          'interface',
          'enum',
          'public',
          'private',
          'protected',
          'internal',
          'static',
          'readonly',
          'const',
          'void',
          'var',
          'new',
          'return',
          'if',
          'else',
          'switch',
          'case',
          'for',
          'foreach',
          'while',
          'do',
          'break',
          'continue',
          'try',
          'catch',
          'finally',
          'throw',
          'true',
          'false',
          'null',
          'async',
          'await',
        };
      case 6: // CMD
        return {'echo', 'set', 'if', 'else', 'for', 'in', 'goto', 'call', 'exit'};
      case 8: // HTML
      case 14: // XML
        return const {}; // tag highlighting handled separately
      case 9: // Java
        return {
          'package',
          'import',
          'class',
          'interface',
          'enum',
          'public',
          'private',
          'protected',
          'static',
          'final',
          'void',
          'var',
          'new',
          'return',
          'if',
          'else',
          'switch',
          'case',
          'for',
          'while',
          'do',
          'break',
          'continue',
          'try',
          'catch',
          'finally',
          'throw',
          'true',
          'false',
          'null',
          'this',
          'super',
        };
      case 10: // JavaScript
        return {
          'function',
          'const',
          'let',
          'var',
          'return',
          'if',
          'else',
          'switch',
          'case',
          'for',
          'while',
          'do',
          'break',
          'continue',
          'try',
          'catch',
          'finally',
          'throw',
          'true',
          'false',
          'null',
          'undefined',
          'new',
          'class',
          'extends',
          'import',
          'export',
          'await',
          'async',
          'this',
        };
      case 11: // Markdown (minimal)
        return const {};
      case 12: // PHP
        return {
          'function',
          'class',
          'public',
          'private',
          'protected',
          'static',
          'const',
          'return',
          'if',
          'else',
          'elseif',
          'switch',
          'case',
          'for',
          'foreach',
          'while',
          'do',
          'break',
          'continue',
          'try',
          'catch',
          'finally',
          'throw',
          'true',
          'false',
          'null',
          'new',
          'echo',
        };
      case 13: // Python
        return {
          'def',
          'class',
          'return',
          'if',
          'elif',
          'else',
          'for',
          'while',
          'break',
          'continue',
          'try',
          'except',
          'finally',
          'raise',
          'with',
          'as',
          'import',
          'from',
          'pass',
          'yield',
          'True',
          'False',
          'None',
        };
      default:
        return const {};
    }
  }

  Delta highlightToDelta(String text, int lang) {
    // Flutter Quill documents must end with a newline.
    final normalizedText = text.endsWith('\n') ? text : '$text\n';
    if (lang == 0) {
      return Delta()..insert(normalizedText);
    }

    final keywords = _keywordsFor(lang);
    final keywordPart =
        keywords.isEmpty ? r'(?!)' : keywords.map(RegExp.escape).join('|');

    final isMarkup = (lang == 8 || lang == 14);
    final tagPart = isMarkup ? r'</?[\w:\-]+(?:\s+[^>]*?)?>' : r'(?!)';
    final commentPart = switch (lang) {
      2 => r'#.*?$',
      6 => r'REM.*?$',
      13 => r'#.*?$',
      _ => r'//.*?$|/\*.*?\*/',
    };

    final tokenPattern =
        '($commentPart'
        '|\'(?:\\\\.|[^\'\\\\])*\''
        '|\\"(?:\\\\.|[^"\\\\])*\\"'
        '|\\b\\d+(?:\\.\\d+)?\\b'
        '|\\b(?:$keywordPart)\\b'
        '|$tagPart'
        ')';

    final tokenRe = RegExp(
      tokenPattern,
      multiLine: true,
      dotAll: true,
      caseSensitive: lang != 6, // CMD REM is case-insensitive in practice
    );

    final delta = Delta();
    var i = 0;
    for (final m in tokenRe.allMatches(normalizedText)) {
      if (m.start > i) {
        delta.insert(normalizedText.substring(i, m.start));
      }
      final token = normalizedText.substring(m.start, m.end);
      final attrs = <String, dynamic>{};

      final lower = token.toLowerCase();
      final isNumber = RegExp(r'^\d').hasMatch(token);
      final isString = token.startsWith("'") || token.startsWith('"');
      final isComment = switch (lang) {
        2 => token.startsWith('#'),
        6 => lower.startsWith('rem'),
        13 => token.startsWith('#'),
        _ => token.startsWith('//') || token.startsWith('/*'),
      };
      final isTag = isMarkup && (token.startsWith('<') || token.startsWith('</'));
      final isKeyword =
          !isTag && !isComment && !isString && !isNumber && keywords.isNotEmpty;

      if (isComment) {
        attrs['color'] = _colors['comment'];
      } else if (isString) {
        attrs['color'] = _colors['string'];
      } else if (isNumber) {
        attrs['color'] = _colors['number'];
      } else if (isTag) {
        attrs['color'] = _colors['tag'];
      } else if (isKeyword) {
        attrs['color'] = _colors['keyword'];
      }

      delta.insert(token, attrs);
      i = m.end;
    }

    if (i < normalizedText.length) {
      delta.insert(normalizedText.substring(i));
    }

    return delta;
  }

  Iterable<({int start, int end, String? color})> tokenize(String text, int lang) sync* {
    if (lang == 0) return;

    final normalizedText = text;
    final keywords = _keywordsFor(lang);
    final keywordPart =
        keywords.isEmpty ? r'(?!)' : keywords.map(RegExp.escape).join('|');

    final isMarkup = (lang == 8 || lang == 14);
    final tagPart = isMarkup ? r'</?[\w:\-]+(?:\s+[^>]*?)?>' : r'(?!)';
    final commentPart = switch (lang) {
      2 => r'#.*?$',
      6 => r'REM.*?$',
      13 => r'#.*?$',
      _ => r'//.*?$|/\*.*?\*/',
    };

    final tokenPattern =
        '($commentPart'
        '|\'(?:\\\\.|[^\'\\\\])*\''
        '|\\"(?:\\\\.|[^"\\\\])*\\"'
        '|\\b\\d+(?:\\.\\d+)?\\b'
        '|\\b(?:$keywordPart)\\b'
        '|$tagPart'
        ')';

    final tokenRe = RegExp(
      tokenPattern,
      multiLine: true,
      dotAll: true,
      caseSensitive: lang != 6,
    );

    for (final m in tokenRe.allMatches(normalizedText)) {
      final token = normalizedText.substring(m.start, m.end);
      yield (start: m.start, end: m.end, color: colorForToken(token, lang));
    }
  }

  /// Replaces all occurrences of [from] with [to] in the given [controller].
  /// Updates the QuillEditor immediately.
  ///
  /// - Does nothing if [from] is empty.
  /// - Works on the editor's plain text view.
  void replace(String from, String to, QuillController controller) {
    if (from.isEmpty) return;

    var text = controller.document.toPlainText();
    if (text.isEmpty) return;

    var start = 0;
    while (true) {
      final idx = text.indexOf(from, start);
      if (idx == -1) break;

      controller.replaceText(
        idx,
        from.length,
        to,
        controller.selection,
      );

      // After replaceText, the document has changed; recompute text and move on.
      final newText = controller.document.toPlainText();
      start = idx + to.length;
      if (newText == text) break;
      text = newText;
    }
  }

  void _writeMathResult(
    QuillController controller,
    double value,
  ) {
    final resultText = value.isFinite
        ? (value == value.truncateToDouble()
            ? value.toInt().toString()
            : value.toString())
        : value.toString();
    final textToInsert = '$resultText\n';
    final offset = controller.selection.baseOffset < 0
        ? controller.document.length - 1
        : controller.selection.baseOffset;
    controller.replaceText(
      offset,
      0,
      textToInsert,
      TextSelection.collapsed(offset: offset + textToInsert.length),
    );
  }

  void mathPlus(double a, double b, QuillController controller) =>
      _writeMathResult(controller, a + b);

  void mathMinus(double a, double b, QuillController controller) =>
      _writeMathResult(controller, a - b);

  void mathMultiply(double a, double b, QuillController controller) =>
      _writeMathResult(controller, a * b);

  void mathDivide(double a, double b, QuillController controller) =>
      _writeMathResult(controller, a / b);

  void mathPower(double a, double b, QuillController controller) =>
      _writeMathResult(controller, math.pow(a, b).toDouble());

  void mathRoot(double a, double b, QuillController controller) =>
      _writeMathResult(controller, math.pow(a, 1 / b).toDouble());

  void mathLog(double a, double b, QuillController controller) =>
      _writeMathResult(controller, math.log(b) / math.log(a));

  void mathSin(double a, QuillController controller) =>
      _writeMathResult(controller, math.sin(a));

  void mathCos(double a, QuillController controller) =>
      _writeMathResult(controller, math.cos(a));

  void mathTan(double a, QuillController controller) =>
      _writeMathResult(controller, math.tan(a));

  void mathCot(double a, QuillController controller) =>
      _writeMathResult(controller, 1 / math.tan(a));

  void mathSec(double a, QuillController controller) =>
      _writeMathResult(controller, 1 / math.cos(a));

  void mathCsc(double a, QuillController controller) =>
      _writeMathResult(controller, 1 / math.sin(a));

  void mathAsin(double a, QuillController controller) =>
      _writeMathResult(controller, math.asin(a));

  void mathAcos(double a, QuillController controller) =>
      _writeMathResult(controller, math.acos(a));

  void mathAtan(double a, QuillController controller) =>
      _writeMathResult(controller, math.atan(a));

  void mathSinh(double a, QuillController controller) =>
      _writeMathResult(controller, (math.exp(a) - math.exp(-a)) / 2);

  void mathCosh(double a, QuillController controller) =>
      _writeMathResult(controller, (math.exp(a) + math.exp(-a)) / 2);

  void mathTanh(double a, QuillController controller) =>
      _writeMathResult(
          controller, (math.exp(a) - math.exp(-a)) / (math.exp(a) + math.exp(-a)));

  void _insertHashHex(QuillController controller, String hexUpper) {
    final textToInsert = '$hexUpper\n';
    final offset = controller.selection.baseOffset < 0
        ? controller.document.length - 1
        : controller.selection.baseOffset;
    controller.replaceText(
      offset,
      0,
      textToInsert,
      TextSelection.collapsed(offset: offset + textToInsert.length),
    );
  }

  String _hashlibHexUtf8Upper(hl.HashBase h, String input) =>
      h.string(input, utf8).hex(true);

  String _pointycastleHexUtf8Upper(Digest digest, String input) {
    final data = Uint8List.fromList(utf8.encode(input));
    digest.reset();
    digest.update(data, 0, data.length);
    final out = Uint8List(digest.digestSize);
    digest.doFinal(out, 0);
    final sb = StringBuffer();
    for (var i = 0; i < out.length; i++) {
      sb.write(out[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString().toUpperCase();
  }

  void hash_md2(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.md2, input));

  void hash_md4(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.md4, input));

  void hash_md5(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.md5, input));

  void hash_sha1(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.sha1, input));

  void hash_sha256(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.sha256, input));

  void hash_sha384(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.sha384, input));

  void hash_sha512(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.sha512, input));

  void hash_ripemd160(String input, QuillController controller) =>
      _insertHashHex(controller, _hashlibHexUtf8Upper(hl.ripemd160, input));

  void hash_whirlpool(String input, QuillController controller) =>
      _insertHashHex(controller, _pointycastleHexUtf8Upper(WhirlpoolDigest(), input));

  void hash_tiger(String input, QuillController controller) =>
      _insertHashHex(controller, _pointycastleHexUtf8Upper(TigerDigest(), input));
}