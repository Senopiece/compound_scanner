import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../utils/faker.dart';

class AnalysisResult {
  // final Future<Uint8List> preprocesedImage;
  final Future<Uint8List> structuralImage;
  final Stream<String> iupac;
  final Stream<String> inchi;
  final Stream<String> smiles;

  AnalysisResult(
    // this.preprocesedImage,
    this.structuralImage,
    this.iupac,
    this.inchi,
    this.smiles,
  );
}

abstract class Analyzer {
  AnalysisResult analyze(Uint8List img);
}

class RestfulDecimerServerAnalyzer implements Analyzer {
  static final Dio _dio = Dio();
  final String baseUrl;

  RestfulDecimerServerAnalyzer(this.baseUrl);

  @override
  AnalysisResult analyze(Uint8List img) {
    final structuralImageFController = Completer<Uint8List>();
    final iupacStreamController = StreamController<String>.broadcast();
    final inchiStreamController = StreamController<String>.broadcast();
    final smilesStreamController = StreamController<String>.broadcast();

    final parallelAsyncRes = AnalysisResult(
      structuralImageFController.future,
      iupacStreamController.stream,
      inchiStreamController.stream,
      smilesStreamController.stream,
    );

    () async {
      try {
        String reqUrl = baseUrl;
        Response resp;
        while (true) {
          resp = await _dio.get(
            reqUrl,
            data: {"image": base64.encode(img)},
            options: Options(
              followRedirects: false,
              validateStatus: (status) {
                return status! < 500;
              },
              headers: {
                "content-type": "application/json",
                "ngrok-skip-browser-warning": "69420",
              },
            ),
          );

          if (resp.statusCode == 303) {
            reqUrl = resp.headers['location']![0];
          } else {
            break;
          }
        }

        final res = resp.data as Map<String, dynamic>;
        structuralImageFController.complete(base64.decode(res['image']!));
        fakeStream(res['inchi']!).listen(
          inchiStreamController.add,
          onError: inchiStreamController.addError,
          onDone: inchiStreamController.close,
        );
        fakeStream(res['iupac']!).listen(
          iupacStreamController.add,
          onError: iupacStreamController.addError,
          onDone: iupacStreamController.close,
        );
        fakeStream(res['smiles']!).listen(
          smilesStreamController.add,
          onError: smilesStreamController.addError,
          onDone: smilesStreamController.close,
        );
      } catch (error, trace) {
        structuralImageFController.completeError(error, trace);

        iupacStreamController.addError(error, trace);
        iupacStreamController.close();

        inchiStreamController.addError(error, trace);
        inchiStreamController.close();

        smilesStreamController.addError(error, trace);
        smilesStreamController.close();
      }
    }();

    return parallelAsyncRes;
  }
}
