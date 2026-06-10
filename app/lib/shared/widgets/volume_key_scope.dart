import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/settings/volume_key_handler.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';
import 'package:todo_app/core/settings/volume_key_settings.dart';

/// 订阅原生音量键事件，同步拦截状态，并按当前 Tab 分发到注册的 handler。
class VolumeKeyScope extends ConsumerStatefulWidget {
  const VolumeKeyScope({
    super.key,
    required this.activeTab,
    required this.child,
  });

  final int activeTab;
  final Widget child;

  @override
  ConsumerState<VolumeKeyScope> createState() => _VolumeKeyScopeState();
}

class _VolumeKeyScopeState extends ConsumerState<VolumeKeyScope> {
  StreamSubscription<VolumeKeyDirection>? _subscription;
  bool _platformSupported = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initPlatform());
  }

  Future<void> _initPlatform() async {
    final supported = await VolumeKeyPlatform.isSupported;
    if (!mounted) return;
    setState(() => _platformSupported = supported);
    if (!supported) return;

    _subscription = VolumeKeyPlatform.events.listen((direction) {
      if (!mounted) return;
      ref.read(volumeKeyHandlerProvider.notifier).dispatch(
            direction,
            activeTab: widget.activeTab,
          );
    });
    _syncIntercept();
  }

  @override
  void didUpdateWidget(VolumeKeyScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab) {
      _syncIntercept();
    }
  }

  void _syncIntercept() {
    if (!_platformSupported) return;

    final enabled = ref.read(volumeKeyShortcutsProvider).value ?? false;
    final handlerState = ref.read(volumeKeyHandlerProvider);
    final onCollect = widget.activeTab == 0 && enabled;
    final onProcess = widget.activeTab == 1 &&
        enabled &&
        !handlerState.processBlocked;
    unawaited(VolumeKeyPlatform.setInterceptEnabled(onCollect || onProcess));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    if (_platformSupported) {
      unawaited(VolumeKeyPlatform.setInterceptEnabled(false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(volumeKeyShortcutsProvider, (_, __) => _syncIntercept());
    ref.listen(volumeKeyHandlerProvider, (_, __) => _syncIntercept());
    return widget.child;
  }
}
