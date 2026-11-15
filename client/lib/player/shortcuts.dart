import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

class MelodiaShortcuts extends ConsumerWidget {
  const MelodiaShortcuts({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider.notifier);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.space): const _PlayPauseIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const _PreviousIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const _NextIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const _VolumeUpIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const _VolumeDownIntent(),
        const SingleActivator(LogicalKeyboardKey.keyM): const _MuteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS): const _ShuffleIntent(),
        const SingleActivator(LogicalKeyboardKey.keyR): const _RepeatIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
            onInvoke: (_) => controller.togglePlayPause(),
          ),
          _SeekBackwardIntent: CallbackAction<_SeekBackwardIntent>(
            onInvoke: (_) => controller.seekRelative(const Duration(seconds: -10)),
          ),
          _SeekForwardIntent: CallbackAction<_SeekForwardIntent>(
            onInvoke: (_) => controller.seekRelative(const Duration(seconds: 10)),
          ),
          _PreviousIntent: CallbackAction<_PreviousIntent>(
            onInvoke: (_) => controller.skipPrevious(),
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) => controller.skipNext(),
          ),
          _VolumeUpIntent: CallbackAction<_VolumeUpIntent>(
            onInvoke: (_) => controller.adjustVolume(0.05),
          ),
          _VolumeDownIntent: CallbackAction<_VolumeDownIntent>(
            onInvoke: (_) => controller.adjustVolume(-0.05),
          ),
          _MuteIntent: CallbackAction<_MuteIntent>(
            onInvoke: (_) => controller.toggleMute(),
          ),
          _ShuffleIntent: CallbackAction<_ShuffleIntent>(
            onInvoke: (_) => controller.toggleShuffle(),
          ),
          _RepeatIntent: CallbackAction<_RepeatIntent>(
            onInvoke: (_) => controller.cycleRepeat(),
          ),
        },
        child: Focus(
          autofocus: true,
          canRequestFocus: false,
          child: child,
        ),
      ),
    );
  }
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _VolumeUpIntent extends Intent {
  const _VolumeUpIntent();
}

class _VolumeDownIntent extends Intent {
  const _VolumeDownIntent();
}

class _MuteIntent extends Intent {
  const _MuteIntent();
}

class _ShuffleIntent extends Intent {
  const _ShuffleIntent();
}

class _RepeatIntent extends Intent {
  const _RepeatIntent();
}

