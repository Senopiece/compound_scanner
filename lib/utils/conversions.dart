import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';

imglib.Image convertYUV420ToImage(
  CameraImage cameraImage, {
  int rotation = 0, // rotation in (0, 90, 180, 270)
}) {
  assert(rotation == 0 || rotation == 90 || rotation == 180 || rotation == 270);
  final imageWidth = cameraImage.width;
  final imageHeight = cameraImage.height;

  final yBuffer = cameraImage.planes[0].bytes;
  final uBuffer = cameraImage.planes[1].bytes;
  final vBuffer = cameraImage.planes[2].bytes;

  final int yRowStride = cameraImage.planes[0].bytesPerRow;
  final int yPixelStride = cameraImage.planes[0].bytesPerPixel!;

  final int uvRowStride = cameraImage.planes[1].bytesPerRow;
  final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

  late imglib.Image image;
  if (rotation % 180 != 0) {
    image = imglib.Image(width: imageHeight, height: imageWidth);
  } else {
    image = imglib.Image(width: imageWidth, height: imageHeight);
  }

  for (int h = 0; h < imageHeight; h++) {
    int uvh = (h / 2).floor();

    for (int w = 0; w < imageWidth; w++) {
      int uvw = (w / 2).floor();

      // Compute rotated coordinates based on rotation parameter.
      int x, y;
      switch (rotation) {
        case 90:
          x = imageHeight - h - 1;
          y = w;
          break;
        case 180:
          x = imageWidth - w - 1;
          y = imageHeight - h - 1;
          break;
        case 270:
          x = h;
          y = imageWidth - w - 1;
          break;
        default:
          x = w;
          y = h;
      }

      final yIndex = (h * yRowStride) + (w * yPixelStride);

      // Y plane should have positive values belonging to [0...255]
      final int yValue = yBuffer[yIndex];

      // U/V Values are subsampled i.e. each pixel in U/V chanel in a
      // YUV_420 image act as chroma value for 4 neighbouring pixels
      final int uvIndex = (uvh * uvRowStride) + (uvw * uvPixelStride);

      // U/V values ideally fall under [-0.5, 0.5] range. To fit them into
      // [0, 255] range they are scaled up and centered to 128.
      // Operation below brings U/V values to [-128, 127].
      final int u = uBuffer[uvIndex];
      final int v = vBuffer[uvIndex];

      // Compute RGB values per formula above.
      int r = (yValue + v * 1436 / 1024 - 179).round();
      int g =
          (yValue - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
      int b = (yValue + u * 1814 / 1024 - 227).round();

      r = r.clamp(0, 255);
      g = g.clamp(0, 255);
      b = b.clamp(0, 255);

      // Set pixel at rotated coordinates.
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  return image;
}
