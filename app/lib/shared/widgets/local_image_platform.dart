import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

Future<Uint8List?> loadLocalImageBytes(String path) async {
  try {
    return await XFile(path).readAsBytes();
  } catch (_) {
    return null;
  }
}
