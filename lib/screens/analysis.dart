import 'dart:typed_data';
import 'dart:developer';

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
    // encode
    late List<List<double>> featuresReshaped;
    {
      final interpreter =
          await Interpreter.fromAsset('assets/models/encoder.tflite');

      final input = interpreter.getInputTensor(0);
      final inputW = input.shape[1];
      final inputH = input.shape[2];
      final inputDepth = input.shape[3];

      final image = imglib.decodeImage(imageBytes);

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
      final inputImage = List.generate(
          inputW,
          (index) => List.generate(
              inputH, (index) => List<int>.filled(inputDepth, 0)));

      if (input.type != TensorType.float32) {
        interpreter.close();
        return "fail model.pix != float32";
      }

      // Normalize the image pixel values and convert them to a Float32List
      // int pixelIndex = 0;
      num average = 0;
      for (var y = 0; y < inputW; y++) {
        for (var x = 0; x < inputH; x++) {
          final pixel = resizedImage.getPixel(x, y);
          inputImage[x][y][0] = pixel.r.toInt();
          inputImage[x][y][1] = pixel.g.toInt();
          inputImage[x][y][2] = pixel.b.toInt();
          average += pixel.b.toInt();
        }
      }
      average /= inputW * inputH;
      // print(inputImage[0][0]);
      print(average);
      print(inspect(inputImage));

      // input.data = inputImage.buffer.asUint8List();

      final outputTensor = interpreter.getOutputTensor(0);
      var output = [
        List.generate(outputTensor.shape[1],
            (index) => List<double>.filled(outputTensor.shape[2], 0))
      ];
      interpreter.run([inputImage], output);
      final features = output;
      featuresReshaped = features[0];

      print(outputTensor.shape);
      print(outputTensor.type);
      print(output[0][0]);

      interpreter.close();
    }

    // get initial state
    late List<double> hiddenState, memoryState;
    {
      final interpreter =
          await Interpreter.fromAsset('assets/models/isg.tflite');

      print(interpreter.getOutputTensors());
      final outputs = {
        0: [List<double>.filled(1024, 0)], // hidden
        1: [List<double>.filled(1024, 0)] // memory
      };
      interpreter.runForMultipleInputs([
        [featuresReshaped]
      ], outputs);
      hiddenState = outputs[0]![0];
      memoryState = outputs[1]![0];
      // print(hiddenState);
      // print(memoryState);
    }

    // decode
    String res = token_map.map[1];
    {
      final interpreter =
          await Interpreter.fromAsset('assets/models/decoder.tflite');

      // final encoderMean = features.reduce((a, b) => a + b) / features.length;

      var tokenProbabilities = List<double>.filled(197, 0);
      var hidden = hiddenState;
      var memory = memoryState;
      var prevPred = 1;
      for (var i = 0; i < 10; i++) {
        final outputs = {
          1: [tokenProbabilities], // token probabilities
          0: [List<double>.filled(1024, 0)], // hidden
          2: [List<double>.filled(1024, 0)], // memory
        };

        interpreter.runForMultipleInputs(
          [
            [
              [prevPred]
            ],
            [featuresReshaped], // image features
            [hidden], // hidden
            [memory], // memory
          ],
          outputs,
        );

        memory = outputs[2]![0];
        hidden = outputs[0]![0];
        tokenProbabilities = outputs[1]![0];

        // print(hidden);
        // print(memory);
        // print(tokenProbabilities);

        prevPred = argmax(tokenProbabilities);
        final symbol = token_map.map[prevPred];
        print(symbol);
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
