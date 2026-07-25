import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const _publicDownloadSubdir = 'MoeSocial';

Future<Directory> resolvePublicDownloadDirectory({
  String subdir = _publicDownloadSubdir,
}) async {
  final downloads = await getDownloadsDirectory();
  if (downloads != null && downloads.path.isNotEmpty) {
    final dir = Directory(p.join(downloads.path, subdir));
    await dir.create(recursive: true);
    return dir;
  }

  final fallback = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(fallback.path, subdir));
  await dir.create(recursive: true);
  return dir;
}
