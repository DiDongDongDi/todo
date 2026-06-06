import 'package:flutter/material.dart';
import 'package:todo_app/shared/widgets/local_image.dart';

Future<void> showLocalImagePreview(
  BuildContext context, {
  required List<String> paths,
  int initialIndex = 0,
}) {
  if (paths.isEmpty) return Future.value();

  final index = initialIndex.clamp(0, paths.length - 1);

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _ImagePreviewPage(
          paths: paths,
          initialIndex: index,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ImagePreviewPage extends StatefulWidget {
  const _ImagePreviewPage({
    required this.paths,
    required this.initialIndex,
  });

  final List<String> paths;
  final int initialIndex;

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late final PageController _pageController;
  late final TransformationController _transformController;
  late int _currentIndex;
  double _scale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformController = TransformationController();
    _transformController.addListener(_onTransformUpdate);
  }

  void _onTransformUpdate() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _scale).abs() > 0.01) {
      setState(() => _scale = scale);
    }
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
    _scale = 1.0;
  }

  void _onImageTap() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.removeListener(_onTransformUpdate);
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.paths.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: multi ? Text('${_currentIndex + 1} / ${widget.paths.length}') : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.paths.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          _resetTransform();
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.5,
            maxScale: 4,
            panEnabled: _scale > 1.01,
            child: GestureDetector(
              onTap: _onImageTap,
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: LocalImage(
                  widget.paths[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
