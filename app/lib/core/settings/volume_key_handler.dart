import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/settings/volume_key_platform.dart';

typedef VolumeKeyHandler = void Function(VolumeKeyDirection direction);

/// 当前活跃页面注册的音量键处理器（收集 / 处理页各注册一个）。
class VolumeKeyHandlerState {
  const VolumeKeyHandlerState({
    this.collect,
    this.process,
    this.processBlocked = false,
  });

  final VolumeKeyHandler? collect;
  final VolumeKeyHandler? process;
  final bool processBlocked;
}

class VolumeKeyHandlerNotifier extends Notifier<VolumeKeyHandlerState> {
  @override
  VolumeKeyHandlerState build() => const VolumeKeyHandlerState();

  void registerCollect(VolumeKeyHandler? handler) {
    state = VolumeKeyHandlerState(
      collect: handler,
      process: state.process,
      processBlocked: state.processBlocked,
    );
  }

  void registerProcess(VolumeKeyHandler? handler) {
    state = VolumeKeyHandlerState(
      collect: state.collect,
      process: handler,
      processBlocked: state.processBlocked,
    );
  }

  void setProcessBlocked(bool blocked) {
    if (state.processBlocked == blocked) return;
    state = VolumeKeyHandlerState(
      collect: state.collect,
      process: state.process,
      processBlocked: blocked,
    );
  }

  void dispatch(VolumeKeyDirection direction, {required int activeTab}) {
    if (activeTab == 0) {
      state.collect?.call(direction);
      return;
    }
    if (activeTab == 1 && !state.processBlocked) {
      state.process?.call(direction);
    }
  }
}

final volumeKeyHandlerProvider =
    NotifierProvider<VolumeKeyHandlerNotifier, VolumeKeyHandlerState>(
  VolumeKeyHandlerNotifier.new,
);
