import 'file_saver_helper_stub.dart'
    if (dart.library.io) 'file_saver_helper_io.dart'
    if (dart.library.html) 'file_saver_helper_web.dart'
    as implementation;

class FileSaverHelper {
  static Future<String?> saveFile({
    required String fileName,
    required String content,
  }) async {
    return implementation.saveFile(
      fileName: fileName,
      content: content,
    );
  }

  static Future<String?> pickAndReadFile() async {
    return implementation.pickAndReadFile();
  }
}
