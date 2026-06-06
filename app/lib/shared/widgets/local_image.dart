import 'package:flutter/widgets.dart';

import 'local_image_platform.dart'
    if (dart.library.io) 'local_image_io.dart';

class LocalImage extends StatelessWidget {
  const LocalImage(
    this.path, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return buildLocalImage(
      path,
      fit: fit,
      width: width,
      height: height,
    );
  }
}
