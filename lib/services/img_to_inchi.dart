import 'dart:isolate';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/token_map.dart' as token_map;
import 'package:image/image.dart' as imglib;

import 'package:tflite_flutter/tflite_flutter.dart';

int argmax(List<dynamic> X) {
  int idx = 0;
  int l = X.length;
  for (int i = 0; i < l; i++) {
    idx = X[i] > X[idx] ? i : idx;
  }
  return idx;
}

Future<Uint8List> loadModelFromAsset(String asset) async {
  ByteData rawAssetFile = await rootBundle.load('assets/models/$asset.tflite');
  return rawAssetFile.buffer.asUint8List();
}

// TODO: forbid to run when already running
Stream<String> imgToInchi(Uint8List imageBytes) async* {
  late List<List<double>> features;
  {
    final encoder = await loadModelFromAsset('encoder');
    features = await Isolate.run(
      () async => await _encode(encoder, imageBytes),
    );
  }

  late List<List<double>> init;
  {
    final isg = await loadModelFromAsset('isg');
    init = await Isolate.run(
      () async => await _isg(isg, features),
    );
  }

  {
    var res = token_map.map[1];
    final decoder = await loadModelFromAsset('decoder');
    ReceivePort receivePort = ReceivePort();
    await Isolate.spawn(
      _decode,
      [decoder, init, features, receivePort.sendPort],
    );
    await for (var symbol in receivePort) {
      res += symbol;
      yield res;
    }
  }
}

Future<List<List<double>>> _encode(
  Uint8List encoderBytes,
  Uint8List imageBytes,
) async {
  late List<List<double>> featuresReshaped;
  final interpreter = Interpreter.fromBuffer(encoderBytes);

  final input = interpreter.getInputTensor(0);
  final inputW = input.shape[1];
  final inputH = input.shape[2];
  final inputDepth = input.shape[3];

  final image = imglib.decodeImage(imageBytes);

  // TODO: resize by filling gaps
  final resizedImage = imglib.copyResize(
    image!,
    width: inputW,
    height: inputH,
  );
  final inputImage = List.generate(
    inputW,
    (index) => List.generate(
      inputH,
      (index) => List<int>.filled(inputDepth, 0),
    ),
  );

  // Normalize the image pixel values and convert them to a Float32List
  // int pixelIndex = 0;
  for (var y = 0; y < inputH; y++) {
    for (var x = 0; x < inputW; x++) {
      final pixel = resizedImage.getPixel(x, y);
      inputImage[y][x][0] = pixel.r.toInt();
      inputImage[y][x][1] = pixel.g.toInt();
      inputImage[y][x][2] = pixel.b.toInt();
    }
  }

  // input.data = inputImage.buffer.asUint8List();

  final outputTensor = interpreter.getOutputTensor(0);
  var output = [
    List.generate(outputTensor.shape[1],
        (index) => List<double>.filled(outputTensor.shape[2], 0))
  ];
  interpreter.run([inputImage], output);
  final features = output;
  featuresReshaped = features[0];

  interpreter.close();

  return featuresReshaped;
}

Future<List<List<double>>> _isg(
  Uint8List isgBytes,
  List<List<double>> features,
) async {
  // get initial state
  late List<double> hiddenState, memoryState;
  final interpreter = Interpreter.fromBuffer(isgBytes);

  final outputs = {
    0: [List<double>.filled(1024, 0)], // hidden
    1: [List<double>.filled(1024, 0)] // memory
  };
  interpreter.runForMultipleInputs([
    [features]
  ], outputs);
  hiddenState = outputs[0]![0];
  memoryState = outputs[1]![0];

  return [hiddenState, memoryState];
}

void _decode(List<dynamic> args) {
  final Uint8List decodeBytes = args[0];
  final List<List<double>> init = args[1];
  final List<List<double>> features = args[2];
  final SendPort sendPort = args[3];

  final interpreter = Interpreter.fromBuffer(decodeBytes);

  // final encoderMean = features.reduce((a, b) => a + b) / features.length;

  var tokenProbabilities = List<double>.filled(197, 0);
  var hidden = init[0];
  var memory = init[1];
  var prevPred = 1;
  for (var i = 0; i < 30; i++) {
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
        [features], // image features
        [memory], // hidden
        [hidden], // memory
      ],
      outputs,
    );

    memory = outputs[2]![0];
    hidden = outputs[0]![0];
    tokenProbabilities = outputs[1]![0];

    prevPred = argmax(tokenProbabilities);
    final symbol = token_map.map[prevPred];
    debugPrint(symbol);
    if (symbol == "<END>") break;
    sendPort.send(symbol);
  }

  interpreter.close();
}
