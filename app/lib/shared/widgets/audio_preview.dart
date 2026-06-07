import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:todo_app/core/auth/auth_service.dart';
import 'package:todo_app/core/models/task.dart';
import 'package:todo_app/core/sync/attachment_upload_service.dart';
import 'package:todo_app/shared/utils/audio_storage.dart';

Future<void> showAttachmentAudioPreview(
  BuildContext context, {
  required List<TaskAttachment> attachments,
  int initialIndex = 0,
}) {
  if (attachments.isEmpty) return Future.value();

  final index = initialIndex.clamp(0, attachments.length - 1);

  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, animation, secondaryAnimation) {
        return _AttachmentAudioPreviewPage(
          attachments: attachments,
          initialIndex: index,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _AttachmentAudioPreviewPage extends StatefulWidget {
  const _AttachmentAudioPreviewPage({
    required this.attachments,
    required this.initialIndex,
  });

  final List<TaskAttachment> attachments;
  final int initialIndex;

  @override
  State<_AttachmentAudioPreviewPage> createState() =>
      _AttachmentAudioPreviewPageState();
}

class _AttachmentAudioPreviewPageState
    extends State<_AttachmentAudioPreviewPage> {
  final _uploadService = AttachmentUploadService();
  final _player = AudioPlayer();

  late final PageController _pageController;
  late int _currentIndex;

  bool _loading = true;
  String? _error;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _bindPlayerEvents();
    unawaited(_loadAndPlay(_currentIndex));
  }

  void _bindPlayerEvents() {
    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _duration = duration);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  Future<void> _loadAndPlay(int index) async {
    setState(() {
      _loading = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _playing = false;
    });

    await _player.stop();

    final attachment = widget.attachments[index];
    final source = await _uploadService.resolveDisplaySource(
      attachment: attachment,
      client: AuthService.instance.client,
    );

    if (!mounted) return;

    if (source == null) {
      setState(() {
        _loading = false;
        _error = '无法加载录音';
      });
      return;
    }

    try {
      final playerSource = AttachmentUploadService.isHttpUrl(source)
          ? UrlSource(source)
          : DeviceFileSource(source);

      final recordedDuration = attachment.duration;
      if (recordedDuration != null && recordedDuration > 0) {
        _duration = Duration(seconds: recordedDuration);
      }

      await _player.setSource(playerSource);
      if (!mounted) return;

      setState(() => _loading = false);
      await _player.resume();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '播放失败';
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_loading || _error != null) return;

    if (_playing) {
      await _player.pause();
      return;
    }

    if (_position >= _duration && _duration > Duration.zero) {
      await _player.seek(Duration.zero);
    }
    await _player.resume();
  }

  Future<void> _seekTo(double value) async {
    if (_duration <= Duration.zero) return;
    final target = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    await _player.seek(target);
    if (!mounted) return;
    setState(() => _position = target);
  }

  Future<void> _onPageChanged(int index) async {
    setState(() => _currentIndex = index);
    await _loadAndPlay(index);
  }

  void _close() {
    Navigator.of(context).pop();
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    if (totalSeconds <= 0) return '0:00';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_completeSub?.cancel());
    unawaited(_stateSub?.cancel());
    unawaited(_player.dispose());
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = widget.attachments.length > 1;
    final attachment = widget.attachments[_currentIndex];
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: multi
            ? Text('${_currentIndex + 1} / ${widget.attachments.length}')
            : null,
      ),
      body: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.attachments.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            return Center(
              child: GestureDetector(
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic_none_outlined,
                        size: 72,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      if (attachment.duration != null &&
                          attachment.duration! > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          formatAudioDuration(attachment.duration),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      if (_loading)
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else if (_error != null)
                        Text(
                          _error!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        )
                      else ...[
                        IconButton.filled(
                          onPressed: _togglePlayback,
                          iconSize: 40,
                          icon: Icon(
                            _playing ? Icons.pause : Icons.play_arrow,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(72, 72),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                            overlayColor: Colors.white24,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged:
                                _duration > Duration.zero ? _seekTo : null,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              _formatDuration(_duration),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
