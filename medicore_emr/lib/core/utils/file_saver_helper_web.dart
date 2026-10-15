// ignore_for_file: depend_on_referenced_packages
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> saveFile({
  required String fileName,
  required String content,
}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    web.URL.revokeObjectURL(url);
    return 'Descargas (Navegador)';
  } catch (e) {
    return null;
  }
}

Future<String?> pickAndReadFile() async {
  return null;
}
