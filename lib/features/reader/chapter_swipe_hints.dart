import 'package:flutter/material.dart';

class ChapterSwipeHints extends StatefulWidget {
  const ChapterSwipeHints({
    super.key,
    required this.showPrevious,
    required this.showNext,
    required this.color,
  });

  final bool showPrevious;
  final bool showNext;
  final Color color;

  @override
  State<ChapterSwipeHints> createState() => _ChapterSwipeHintsState();
}

class _ChapterSwipeHintsState extends State<ChapterSwipeHints>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _entryController;
  late final Animation<double> _opacity;
  late final Animation<double> _entryOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.15, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_opacity, _entryOpacity]),
        builder: (context, child) {
          final opacity = _opacity.value * _entryOpacity.value;
          return Stack(
            children: [
              if (widget.showPrevious)
                _EdgeHint(
                  alignment: Alignment.centerLeft,
                  opacity: opacity,
                  color: widget.color,
                  icon: Icons.chevron_left,
                  gradientBegin: Alignment.centerLeft,
                  gradientEnd: Alignment.centerRight,
                ),
              if (widget.showNext)
                _EdgeHint(
                  alignment: Alignment.centerRight,
                  opacity: opacity,
                  color: widget.color,
                  icon: Icons.chevron_right,
                  gradientBegin: Alignment.centerRight,
                  gradientEnd: Alignment.centerLeft,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EdgeHint extends StatelessWidget {
  const _EdgeHint({
    required this.alignment,
    required this.opacity,
    required this.color,
    required this.icon,
    required this.gradientBegin,
    required this.gradientEnd,
  });

  final Alignment alignment;
  final double opacity;
  final Color color;
  final IconData icon;
  final Alignment gradientBegin;
  final Alignment gradientEnd;

  @override
  Widget build(BuildContext context) {
    final isLeft = alignment == Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 56,
        height: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: gradientBegin,
              end: gradientEnd,
              colors: [
                color.withValues(alpha: opacity * 0.35),
                color.withValues(alpha: 0),
              ],
            ),
          ),
          child: Align(
            alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(left: isLeft ? 4 : 0, right: isLeft ? 0 : 4),
              child: Icon(
                icon,
                size: 32,
                color: color.withValues(alpha: opacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
