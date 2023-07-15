import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class All {
  final Uint8List image;
  final String iupac;
  final String inchi;

  All(this.image, this.iupac, this.inchi);
}

final Dio _dio = Dio();
const service = "http://192.168.0.201:4269/convert";

Future<All> smilesToAll(String smiles) async {
  final response = await _dio.post(
    service,
    data: {"smiles": smiles},
    options: Options(
      headers: {
        "content-type": "application/json",
      },
    ),
  );
  final json = response.data;
  final img = base64.decode(json['image']);
  return All(img, json['iupac'], json['inchi']);
}
