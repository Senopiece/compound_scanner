import 'package:flutter/material.dart';

class BlinkingCursor extends StatefulWidget {
  final Color cursorColor;
  final double cursorWidth;
  final double cursorHeight;
  final Duration blinkDuration;

  const BlinkingCursor({
    Key? key,
    this.cursorColor = Colors.white,
    this.cursorWidth = 2.0,
    this.cursorHeight = 20.0,
    this.blinkDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.blinkDuration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        _isVisible = _animationController.value < 0.5;
        return Container(
          height: widget.cursorHeight,
          width: widget.cursorWidth,
          color: _isVisible ? widget.cursorColor : Colors.transparent,
        );
      },
    );
  }
}
