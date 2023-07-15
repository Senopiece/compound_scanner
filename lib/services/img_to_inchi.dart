// import 'dart:isolate';
// import 'dart:async';
// import 'dart:typed_data';

// import 'package:flutter/services.dart';

// import '../utils/model_loader.dart';
// import '../utils/token_map.dart' as token_map;
// import 'package:image/image.dart' as imglib;

// import 'package:tflite_flutter/tflite_flutter.dart';

// // TODO: forbid to run when already running
// Stream<String> imgToInchi(Uint8List imageBytes) async* {
//   late List<List<double>> features;
//   {
//     final encoder = await loadModelFromAsset('encoder');
//     features = await Isolate.run(
//       () => _encode(encoder, imageBytes),
//     );
//   }

//   late List<List<List<double>>> init;
//   {
//     final isg = await loadModelFromAsset('isg');
//     init = await Isolate.run(
//       () => _isg(isg, features),
//     );
//   }

//   {
//     var res = token_map.map[1];
//     final decoder = await loadModelFromAsset('decoder');
//     ReceivePort receivePort = ReceivePort();
//     await Isolate.spawn(
//       _decode,
//       [decoder, init, features, receivePort.sendPort],
//     );
//     await for (var symbol in receivePort) {
//       if (symbol == "<END>") break;
//       res += symbol;
//       yield res;
//     }
//   }
// }

// int argmax(List<dynamic> X) {
//   int idx = 0;
//   int l = X.length;
//   for (int i = 0; i < l; i++) {
//     idx = X[i] > X[idx] ? i : idx;
//   }
//   return idx;
// }

// List<List<double>> _encode(
//   Uint8List encoderBytes,
//   Uint8List imageBytes,
// ) {
//   late List<List<double>> featuresReshaped;
//   final interpreter = Interpreter.fromBuffer(encoderBytes);

//   final input = interpreter.getInputTensor(0);
//   final inputW = input.shape[2];
//   final inputH = input.shape[1];
//   final inputDepth = input.shape[3];

//   final image = imglib.decodeImage(imageBytes);

//   // TODO: make the input image have the same aspect ratio as the input tensor, then resize the image
//   final resizedImage = imglib.copyResize(
//     image!,
//     width: inputW,
//     height: inputH,
//   );
//   final inputImage = List.generate(
//     inputW,
//     (index) => List.generate(
//       inputH,
//       (index) => List<int>.filled(inputDepth, 0),
//     ),
//   );

//   // grayscale
//   var colorSum = 0;
//   for (var y = 0; y < inputH; y++) {
//     for (var x = 0; x < inputW; x++) {
//       final pixel = resizedImage.getPixel(x, y);
//       var color = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).toInt();
//       inputImage[x][y][0] = color;
//       inputImage[x][y][1] = color;
//       inputImage[x][y][2] = color;
//       colorSum += color;
//     }
//   }

//   // inverse image if needed
//   if (colorSum / (inputW * inputH) >= 128) {
//     for (var y = 0; y < inputH; y++) {
//       for (var x = 0; x < inputW; x++) {
//         var color = 255 - inputImage[x][y][0];
//         inputImage[x][y][0] = color;
//         inputImage[x][y][1] = color;
//         inputImage[x][y][2] = color;
//       }
//     }
//   }

//   final outputTensor = interpreter.getOutputTensor(0);
//   var output = [
//     List.generate(outputTensor.shape[1],
//         (index) => List<double>.filled(outputTensor.shape[2], 0))
//   ];
//   interpreter.run([inputImage], output);
//   final features = output;
//   featuresReshaped = features[0];

//   interpreter.close();

//   return featuresReshaped;
// }

// List<List<List<double>>> _isg(
//   Uint8List isgBytes,
//   List<List<double>> features,
// ) {
//   // get initial state
//   late List<List<List<double>>> initialState;
//   final interpreter = Interpreter.fromBuffer(isgBytes);

//   final outputTensors = interpreter.getOutputTensors();

//   final outputs = {
//     0: [
//       [List<double>.filled(outputTensors[0].shape[2], 0)],
//       [List<double>.filled(outputTensors[0].shape[2], 0)]
//     ],
//   };
//   interpreter.runForMultipleInputs([
//     [features]
//   ], outputs);
//   initialState = outputs[0]!;

//   return initialState;
// }

// // TODO: catch and forward exceptions
// void _decode(List<dynamic> args) {
//   final Uint8List decodeBytes = args[0];
//   final List<List<List<double>>> initialState = args[1];
//   final List<List<double>> features = args[2];
//   final SendPort sendPort = args[3];

//   final interpreter = Interpreter.fromBuffer(decodeBytes);

//   var tokenProbabilities = List<double>.filled(197, 0);
//   var prevPred = 1;
//   var state = initialState;
//   for (var i = 0; i < 30; i++) {
//     // TODO: set 300 iterations for production
//     final outputs = {
//       1: [tokenProbabilities],
//       0: state,
//     };

//     interpreter.runForMultipleInputs(
//       [
//         state,
//         [features], // image features
//         [
//           [prevPred]
//         ]
//       ],
//       outputs,
//     );

//     state = outputs[0] as List<List<List<double>>>;
//     tokenProbabilities = outputs[1]![0] as List<double>;

//     prevPred = argmax(tokenProbabilities);
//     final symbol = token_map.map[prevPred];
//     if (symbol == "<END>") break;
//     sendPort.send(symbol);
//   }
//   sendPort.send("<END>");
//   interpreter.close();
// }
