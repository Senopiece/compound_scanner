import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../utils/token_map.dart' as token_map;

import 'package:image/image.dart' as imglib;

// import 'package:pytorch_mobile/pytorch_mobile.dart';

int argmax(List<dynamic> X) {
  int idx = 0;
  int l = X.length;
  for (int i = 0; i < l; i++) {
    idx = X[i] > X[idx] ? i : idx;
  }
  return idx;
}

class AnalysisScreen extends StatelessWidget {
  final Uint8List imageBytes;

  const AnalysisScreen({Key? key, required this.imageBytes}) : super(key: key);

  static Future<String> _analyze(Uint8List imageBytes) async {
    // final model = await FlutterPytorch.loadClassificationModel(
    //     "assets/models/model.ptl", 260, 260);
    // return (await model.getImagePredictionList(imageBytes)).toString();

    // encode
    late Uint8List features;
    {
      final interpreter =
          await Interpreter.fromAsset('assets/models/encoder.tflite');

      final input = interpreter.getInputTensor(0);
      final inputW = input.shape[1];
      final inputH = input.shape[2];
      final inputDepth = input.shape[3];

      final image = imglib.decodePng(imageBytes);

      if (image == null) {
        interpreter.close();
        return "fail img=null";
      }

      if (inputDepth != 3) {
        interpreter.close();
        return "fail img != rgb";
      }

      final resizedImage = imglib.copyResize(
        image,
        width: inputW,
        height: inputH,
      );
      final inputImage = Float32List(inputW * inputH * inputDepth);

      if (input.type != TensorType.float32) {
        interpreter.close();
        return "fail model.pix != float32";
      }

      // Normalize the image pixel values and convert them to a Float32List
      int pixelIndex = 0;
      for (var y = 0; y < inputW; y++) {
        for (var x = 0; x < inputH; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputImage[pixelIndex++] = pixel.r / 255.0;
          inputImage[pixelIndex++] = pixel.g / 255.0;
          inputImage[pixelIndex++] = pixel.b / 255.0;
        }
      }

      input.data = inputImage.buffer.asUint8List();

      final output = interpreter.getOutputTensor(0);
      interpreter.invoke();
      features = output.data;

      print(output.type);

      interpreter.close();
    }

    // decode
    var res = "";
    {
      final interpreter =
          await Interpreter.fromAsset('assets/models/decoder.tflite');

      final input = interpreter.getInputTensor(0);

      if (input.type != TensorType.float32) {
        interpreter.close();
        return "failed decoder.input.type != float32";
      }

      if (input.shape[0] != 1) {
        interpreter.close();
        return "failed decoder.shape[0] != 1";
      }

      if (input.numBytes() % features.length == 0) {
        interpreter.close();
        return "failed decoder.len % features.length";
      }

      for (int s = 0; s != features.lengthInBytes; s += input.numBytes()) {
        input.data = features.sublist(s, s + input.numBytes());
        final output = interpreter.getOutputTensor(0);
        interpreter.invoke();
        final list = output.data.buffer.asFloat32List();
        print(list);
        print(argmax(list));
        final symbol = token_map.map[argmax(list)];
        if (symbol == "<END>") break;
        res += symbol;
      }

      interpreter.close();
    }

    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(child: Image.memory(imageBytes)),
            FutureBuilder(
              future: _analyze(imageBytes),
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
