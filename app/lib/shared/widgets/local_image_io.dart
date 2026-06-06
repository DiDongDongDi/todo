import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

Future<Uint8List?> loadLocalImageBytes(String path) async {
  try {
    if (!path.startsWith('content://')) {
      final file = File(path);
      if (await file.exists()) {
        return file.readAsBytes();
      }
    }
    return await XFile(path).readAsBytes();
  } catch (_) {
    return null;
  }
}
