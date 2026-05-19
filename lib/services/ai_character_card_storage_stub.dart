Future<String?> characterCardExportDirectory() async => null;

Future<String> writeCharacterCardExport({
  required String fileName,
  required String content,
}) async {
  throw UnsupportedError('文件导出仅支持移动端与桌面端');
}

String? desktopPickerInitialDirectory(String? exportDir) => null;

Future<String> readFileAtPath(String path) async {
  throw UnsupportedError('文件读取仅支持移动端与桌面端');
}
