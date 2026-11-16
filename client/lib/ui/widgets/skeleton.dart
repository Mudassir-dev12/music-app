import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;

    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: _animation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: tokens.surface2,
            borderRadius: widget.borderRadius ??
                BorderRadius.circular(MelodiaTokens.radiusCard),
          ),
        ),
      ),
    );
  }
}

class SkeletonTrackList extends StatelessWidget {
  const SkeletonTrackList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      padding: const EdgeInsets.symmetric(
        horizontal: MelodiaTokens.spacingLg,
        vertical: MelodiaTokens.spacingSm,
      ),
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: MelodiaTokens.spacingSm),
          child: Row(
            children: [
              SkeletonBox(width: 48, height: 48),
              SizedBox(width: MelodiaTokens.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 140, height: 16),
                    SizedBox(height: 6),
                    SkeletonBox(width: 90, height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: MelodiaTokens.spacingMd),
        itemBuilder: (context, index) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 150, height: 150),
              SizedBox(height: MelodiaTokens.spacingSm),
              SkeletonBox(width: 120, height: 14),
            ],
          );
        },
      ),
    );
  }
}


