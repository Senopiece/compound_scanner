part of '../../services/img_to_smiles.dart';

imglib.Image _resizeByRatio(imglib.Image image) {
  const maxwidth = 512;
  final ratio = maxwidth / max(image.width, image.height);
  final newWidth = (image.width * ratio).toInt();
  final newHeight = (image.height * ratio).toInt();
  final resizedImage = imglib.copyResize(
    image,
    width: newWidth,
    height: newHeight,
    interpolation:
        imglib.Interpolation.cubic, // NOTE: original code had Lanczos
  );
  return resizedImage;
}

imglib.Image _centralSquareImage(imglib.Image image) {
  var maxWh = (1.2 * max(image.width, image.height)).toInt();

  if (maxWh < 512) {
    maxWh = 512;
  }

  final newIm = imglib.Image(
    width: maxWh,
    height: maxWh,
  );

  newIm.clear(
    imglib.ColorRgb8(255, 255, 255),
  ); // TODO: test is it not transparent
  imglib.compositeImage(
    newIm,
    image,
    dstX: (newIm.width - image.width) ~/ 2,
    dstY: (newIm.height - image.height) ~/ 2,
  );

  return newIm;
}

imglib.Image _removeTransparent(Uint8List imageBytes) {
  final src = imglib.decodeImage(imageBytes);

  if (src == null) {
    throw "Unsupported image format";
  }

  final dst = imglib.Image(
    height: src.height,
    width: src.width,
    numChannels: 3,
  );

  imglib.compositeImage(dst, src);

  return dst;
}

imglib.Image _getBNWImage(imglib.Image image) {
  return imglib.contrast(
    imglib.grayscale(image),
    contrast: 180,
  );
}

imglib.Image _getResize(imglib.Image image) {
  final width = image.width;
  final height = image.height;

  if (width == height && width < 512) {
    final resizedImage = imglib.copyResize(
      image,
      width: 512,
      height: 512,
      interpolation:
          imglib.Interpolation.cubic, // NOTE: original code had Lanczos
    );
    return resizedImage;
  } else if (width >= 512 || height >= 512) {
    return image;
  } else {
    return _resizeByRatio(image);
  }
}

List<List<List<double>>> _efnPreprocessInput(imglib.Image image) {
  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];

  final res = List.generate(
    512,
    (index) => List.generate(
      512,
      (index) => List<double>.filled(3, 0),
    ),
  );

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final colorNorm = p.r / 255;
      res[x][y] = List.generate(3, (i) => (colorNorm - mean[i]) / std[i]);
    }
  }

  return res;
}

imglib.Image _decodeImage(Uint8List imageBytes) {
  // In contrast with the original,
  // I reorganized the pipeline as follows
  // because we have no need to accumulate in memory images for all the passed stages
  // (optimization purpose)
  final List<dynamic> stages = [
    _removeTransparent,
    _getBNWImage,
    _getResize,
    _centralSquareImage,
    (img) => imglib.copyResize(
          img,
          width: 512,
          height: 512,
          interpolation: imglib.Interpolation.cubic,
        ),
  ];
  dynamic tmp = imageBytes;
  for (var stage in stages) {
    debugPrint('$stage');
    tmp = stage(tmp);
  }
  return tmp;
}
