import 'package:flutter/material.dart';
import 'dart:async';

class ThreeDotsLoadingIndicator extends StatefulWidget {
  const ThreeDotsLoadingIndicator({super.key});

  @override
  State<ThreeDotsLoadingIndicator> createState() =>
      _ThreeDotsLoadingIndicatorState();
}

class _ThreeDotsLoadingIndicatorState extends State<ThreeDotsLoadingIndicator> {
  late final Timer timer;

  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        currentIndex = (currentIndex + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (index) {
          return AnimatedContainer(
            curve: Curves.easeIn,
            duration: const Duration(milliseconds: 300),
            width: 10.0,
            height: 10.0,
            margin: EdgeInsets.fromLTRB(
              8.0,
              8.0,
              0,
              currentIndex == index ? 13 : 0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}
