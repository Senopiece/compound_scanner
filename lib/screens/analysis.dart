import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../services/img_to_inchi.dart';

class AnalysisScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const AnalysisScreen({Key? key, required this.imageBytes}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(child: Image.memory(imageBytes)),
            StreamBuilder(
              stream: imgToInchi(imageBytes),
              builder: (context, snap) {
                if (snap.hasError) {
                  debugPrint('${snap.error}');
                  debugPrintStack(stackTrace: snap.stackTrace);
                  return const Text("Error");
                } else if (snap.hasData) {
                  return Text(snap.data!);
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
