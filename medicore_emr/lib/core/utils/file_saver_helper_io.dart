import 'dart:io';

Future<String?> saveFile({
  required String fileName,
  required String content,
}) async {
  String? saveDir;
  if (Platform.isWindows) {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null) {
      final downloads = Directory('$userProfile\\Downloads');
      if (downloads.existsSync()) {
        saveDir = downloads.path;
      } else {
        final docs = Directory('$userProfile\\Documents');
        if (docs.existsSync()) {
          saveDir = docs.path;
        }
      }
    }
  }

  saveDir ??= Directory.current.path;
  final file = File('$saveDir${Platform.pathSeparator}$fileName');
  await file.writeAsString(content);
  return file.path;
}

Future<String?> pickAndReadFile() async {
  return null;
}
