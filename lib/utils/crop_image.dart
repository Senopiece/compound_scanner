import 'dart:typed_data';
import 'package:image/image.dart' as img;

Uint8List? cropImage(
  Uint8List bytes, {
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  final cropped = img.copyCrop(
    image,
    x: x.toInt(),
    y: y.toInt(),
    width: width.toInt(),
    height: height.toInt(),
  );
  return img.encodePng(cropped);
}
