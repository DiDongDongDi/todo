import 'dart:io';

import 'package:flutter/material.dart';

Widget buildLocalImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
  );
}
