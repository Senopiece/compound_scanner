import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final Image image;

  const ResultScreen({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Center(
        child: FittedBox(
          child: SizedBox(child: image),
        ),
      ),
    );
  }
}
