import 'dart:math';
import 'package:flutter/material.dart';

class ScreenShake extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double intensity;
  final VoidCallback? onShakeComplete;

  const ScreenShake({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.intensity = 5.0,
    this.onShakeComplete,
  }) : super(key: key);

  @override
  ScreenShakeState createState() => ScreenShakeState();
}

class ScreenShakeState extends State<ScreenShake> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        widget.onShakeComplete?.call();
      }
    });
  }

  void shake() {
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double shake = _animation.value;
        final double dx = (shake > 0 && shake < 1) ? (_random.nextDouble() - 0.5) * widget.intensity * (1 - shake) : 0;
        final double dy = (shake > 0 && shake < 1) ? (_random.nextDouble() - 0.5) * widget.intensity * (1 - shake) : 0;
        
        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
