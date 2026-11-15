import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class ToastService {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(BuildContext context, String message) {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    final entry = OverlayEntry(
      builder: (ctx) => _ToastWidget(
        message: message,
        tokens: tokens,
        onDismiss: () {
          _timer?.cancel();
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(seconds: 3), () {
      _currentEntry?.remove();
      _currentEntry = null;
    });
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.tokens,
    required this.onDismiss,
  });

  final String message;
  final MelodiaTokens tokens;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + MelodiaTokens.spacingMd,
      left: MelodiaTokens.spacingLg,
      right: MelodiaTokens.spacingLg,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: widget.tokens.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MelodiaTokens.spacingLg,
                vertical: MelodiaTokens.spacingMd,
              ),
              decoration: BoxDecoration(
                color: widget.tokens.surface2,
                borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                boxShadow: MelodiaTokens.cardShadow,
                border: Border.all(
                  color: widget.tokens.separator,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: widget.tokens.accent,
                    size: 20,
                  ),
                  const SizedBox(width: MelodiaTokens.spacingMd),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: MelodiaTokens.subhead.copyWith(
                        color: widget.tokens.text,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close_rounded,
                      color: widget.tokens.textSecondary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
