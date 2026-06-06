import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'local_image_platform.dart'
    if (dart.library.io) 'local_image_io.dart';

class LocalImage extends StatefulWidget {
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
  State<LocalImage> createState() => _LocalImageState();
}

class _LocalImageState extends State<LocalImage> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = loadLocalImageBytes(widget.path);
  }

  @override
  void didUpdateWidget(covariant LocalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _bytesFuture = loadLocalImageBytes(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytesFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data != null) {
          return Image.memory(
            data,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, __, ___) => _brokenImage(),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _brokenImage();
      },
    );
  }

  Widget _brokenImage() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
