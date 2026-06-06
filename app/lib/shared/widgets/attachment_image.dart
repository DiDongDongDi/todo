import 'package:flutter/material.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/sync/attachment_upload_service.dart';
import 'package:todo_app/shared/widgets/local_image.dart';

/// 附件图片：本地路径优先，否则通过 Storage 签名 URL 加载。
class AttachmentImage extends StatefulWidget {
  const AttachmentImage(
    this.attachment, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final TaskAttachment attachment;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  State<AttachmentImage> createState() => _AttachmentImageState();
}

class _AttachmentImageState extends State<AttachmentImage> {
  final _uploadService = AttachmentUploadService();
  String? _localPath;
  String? _networkUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.localPath != widget.attachment.localPath ||
        oldWidget.attachment.remoteUrl != widget.attachment.remoteUrl) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    setState(() {
      _loading = true;
      _localPath = null;
      _networkUrl = null;
    });

    final source = await _uploadService.resolveDisplaySource(
      attachment: widget.attachment,
      client: AuthService.instance.client,
    );

    if (!mounted) return;

    if (source == null) {
      setState(() => _loading = false);
      return;
    }

    if (AttachmentUploadService.isHttpUrl(source)) {
      setState(() {
        _networkUrl = source;
        _loading = false;
      });
      return;
    }

    setState(() {
      _localPath = source;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_localPath != null) {
      return LocalImage(
        _localPath!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    if (_networkUrl != null) {
      return Image.network(
        _networkUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
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
        },
        errorBuilder: (_, __, ___) => _brokenImage(),
      );
    }

    if (_loading) {
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
  }

  Widget _brokenImage() {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
