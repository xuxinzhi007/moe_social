import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/public_download_directory.dart';

const _exportSubdir = 'character_cards';

Future<String?> characterCardExportDirectory() async {
  final dir = await resolvePublicDownloadDirectory(
    subdir: p.join('MoeSocial', _exportSubdir),
  );
  return dir.path;
}

Future<String> writeCharacterCardExport({
  required String fileName,
  required String content,
}) async {
  final dirPath = await characterCardExportDirectory();
  if (dirPath == null) {
    throw StateError('无法创建导出目录');
  }
  var name = fileName;
  var file = File(p.join(dirPath, name));
  var index = 2;
  while (await file.exists()) {
    final stem = name.replaceAll(RegExp(r'\.json$'), '');
    name = '${stem}_$index.json';
    file = File(p.join(dirPath, name));
    index++;
  }
  await file.writeAsString(content, encoding: utf8);
  return file.path;
}

String? desktopPickerInitialDirectory(String? exportDir) {
  if (exportDir == null || exportDir.isEmpty) return null;
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    return exportDir;
  }
  return null;
}

Future<String> readFileAtPath(String path) async {
  return File(path).readAsString();
}

Future<List<int>> readBytesAtPath(String path) async {
  return File(path).readAsBytes();
}
