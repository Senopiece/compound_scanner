import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:dio/dio.dart';

import '../utils/fake.dart';

// import 'package:tflite_flutter/tflite_flutter.dart';

// import '../utils/model_loader.dart';

part '../utils/img_to_smiles/preprocess.dart';
part '../utils/img_to_smiles/token_map.dart';

abstract class ImageToSmiles {
  Future<imglib.Image> preprocess(Uint8List img);
  Stream<String> convert(imglib.Image img);
}

class MockmageToSmiles extends ImageToSmiles {
  @override
  Stream<String> convert(imglib.Image img) async* {
    await Future.delayed(const Duration(seconds: 4));
    await for (var e in fakeStream("CN1C=NC2=C1C(=O)N(C(=O)N2C)C")) {
      yield e;
    }
  }

  @override
  Future<imglib.Image> preprocess(Uint8List img) async {
    final res = imglib.decodeImage(img);
    if (res == null) throw "Failed to decode image";
    return res;
  }
}

class RestfulDecimerImageToSmiles extends ImageToSmiles {
  static final Dio _dio = Dio();
  final String baseUrl;

  RestfulDecimerImageToSmiles(this.baseUrl);

  @override
  Stream<String> convert(imglib.Image img) async* {
    final imageTensor = _efnPreprocessInput(img);
    late Response<dynamic> response;
    response = await _dio.post(
      baseUrl,
      data: {"instances": imageTensor},
      options: Options(
        headers: {
          "content-type": "application/json",
        },
      ),
    );
    final predictions =
        (response.data['predictions'][0] as List<dynamic>).cast<int>();
    var accum = "";
    for (var token in predictions) {
      accum += _token_map[token];
      yield accum;
      await Future.delayed(const Duration(milliseconds: 30));
    }
  }

  @override
  Future<imglib.Image> preprocess(Uint8List img) => Isolate.run(
        () => _decodeImage(img),
      );
}

// Future<imglib.Image> preprocess(Uint8List img) => Isolate.run(
//       () => _decodeImage(img),
//     );

// // Recommended to use preprocess() before passing image here
// Stream<String> imgToSmiles(imglib.Image img) async* {
//   final imageTensor = _efnPreprocessInput(img);
//   // late List<List<double>> features;
//   // {
//   //   final encoder = await loadModelFromAsset('encoder_decimer');
//   //   features = await Isolate.run(
//   //     () => _encode(encoder, imageTensor),
//   //   );
//   // }

//   {
//     var res = "";
//     final model = await loadModelFromAsset('decimer');
//     ReceivePort receivePort = ReceivePort();
//     await Isolate.spawn(
//       _decode,
//       [model, imageTensor, receivePort.sendPort],
//     );
//     await for (var symbol in receivePort) {
//       if (symbol == "<end>") break;
//       res += symbol;
//       yield res;
//     }
//   }
// }

// // int argmax(List<dynamic> X) {
// //   int idx = 0;
// //   int l = X.length;
// //   for (int i = 0; i < l; i++) {
// //     idx = X[i] > X[idx] ? i : idx;
// //   }
// //   return idx;
// // }

// // List<List<double>> _encode(
// //   Uint8List encoderBytes,
// //   List<List<List<double>>> imgTensor,
// // ) {
// //   late List<List<double>> features;
// //   final interpreter = Interpreter.fromBuffer(encoderBytes);

// //   final outputTensor = interpreter.getOutputTensor(0);
// //   var output = [
// //     List.generate(outputTensor.shape[1],
// //         (index) => List<double>.filled(outputTensor.shape[2], 0))
// //   ];
// //   interpreter.run([imgTensor], output);
// //   features = output[0];

// //   interpreter.close();

// //   return features;
// // }

// // List<List<List<List<double>>>> createMask(List<List<int>> previousPredictions) {
// //   return List.generate(
// //       previousPredictions.length,
// //       (i) => [
// //             [
// //               [previousPredictions[i][0] == 0 ? 1 : 0]
// //             ]
// //           ]);
// // }

// void _decode(List<dynamic> args) {
//   final Uint8List decodeBytes = args[0];
//   final List<List<List<double>>> imageTensor = args[1];
//   final SendPort sendPort = args[2];

//   final interpreter = Interpreter.fromBuffer(decodeBytes);

//   // var tokenProbabilities = List<double>.filled(_token_map.length, 0);
//   // var previousTokens = [
//   //   [13] // start token
//   // ];
//   // print('>>>>>>');
//   // print(interpreter.getInputTensors());
//   // for (var i = 0; i < 50; i++) {
//   //   print('>>>>>> ' + i.toString());
//   //   print(features.shape);
//   //   var mask = createMask(previousTokens);
//   //   final outputs = {
//   //     0: List.generate(previousTokens.length,
//   //         (index) => [List<double>.filled(_token_map.length, 0)]),
//   //   };

//   //   interpreter.runForMultipleInputs(
//   //     [
//   //       mask,
//   //       [features],
//   //       previousTokens
//   //     ],
//   //     outputs,
//   //   );
//   //   tokenProbabilities = outputs[0]![previousTokens.length - 1][0];

//   //   var predictedToken = argmax(tokenProbabilities);
//   //   final symbol = _token_map[predictedToken];
//   //   if (symbol == "<end>") break;
//   //   sendPort.send(symbol);
//   //   previousTokens.add([predictedToken]);
//   // }
//   List<List<int>> tokens = [List<int>.filled(100, 0)];
//   interpreter.run(imageTensor, tokens);
//   sendPort.send(List.generate(tokens[0].length, (i) => _token_map[tokens[0][i]])
//       .join(""));
//   interpreter.close();
// }
