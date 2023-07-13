import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as imglib;

part '../utils/img_to_smiles/preprocess.dart';

// TODO: in analysys.dart rewrite to use method from here istead of img_to_inchi

Future<Uint8List> preprocess(Uint8List img) async {
  return await Isolate.run(
    () => imglib.encodePng(decodeImage(img)),
  );
}
