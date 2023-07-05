import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pytorch_lite/pytorch_lite.dart';

class ResultScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const ResultScreen({Key? key, required this.imageBytes}) : super(key: key);

  static Future<String> _analyze(Uint8List imageBytes) async {
    final model = await PytorchLite.loadClassificationModel(
        "assets/models/model.ptl", 260, 260);
    return (await model.getImagePredictionList(imageBytes)).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(child: Image.memory(imageBytes)),
            FutureBuilder(
                future: _analyze(imageBytes),
                builder: (context, snap) {
                  if (snap.hasError) {
                    print(snap.error);
                    return const Text("Error");
                  } else if (snap.hasData) {
                    return Text(snap.data!);
                  } else {
                    return const CircularProgressIndicator();
                  }
                }),
          ],
        ),
      ),
    );
  }
}
