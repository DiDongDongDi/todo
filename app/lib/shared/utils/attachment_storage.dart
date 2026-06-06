import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// 将选中的图片复制到应用文档目录，返回可用于 [File] / [LocalImage] 的路径。
Future<String?> persistImageAttachment(XFile file) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }

    final sourcePath = file.path;
    final ext = p.extension(
      sourcePath.isNotEmpty ? sourcePath : file.name,
    );
    final filename = '${const Uuid().v4()}${ext.isEmpty ? '.jpg' : ext}';
    final dest = File(p.join(attachmentsDir.path, filename));
    await dest.writeAsBytes(await file.readAsBytes());
    return dest.path;
  } catch (_) {
    return null;
  }
}
