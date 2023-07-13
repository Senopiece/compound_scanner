part of '../../services/img_to_smiles.dart';

imglib.Image resizeByRatio(imglib.Image image) {
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

imglib.Image centralSquareImage(imglib.Image image) {
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

imglib.Image deleteEmptyBorders(imglib.Image image) {
  // final grayscale = imglib.grayscale(image); // assuming grayscale input

  // mask = image > 200
  const mask_th = 200;

  // rows = np.flatnonzero((~mask).sum(axis=1))
  final rows = <int>[];
  for (var y = 0; y < image.height; y++) {
    var sum = 0;

    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);

      if (pixel.r > mask_th) {
        sum++;
      }
    }

    if (sum > 0) {
      rows.add(y);
    }
  }

  // cols = np.flatnonzero((~mask).sum(axis=0))
  final cols = <int>[];
  for (var x = 0; x < image.width; x++) {
    var sum = 0;

    for (var y = 0; y < image.height; y++) {
      final pixel = image.getPixel(x, y);

      if (pixel.r > mask_th) {
        sum++;
      }
    }

    if (sum > 0) {
      cols.add(x);
    }
  }

  // crop = image[rows.min() : rows.max() + 1, cols.min() : cols.max() + 1]
  final minRow = rows.reduce(min);
  final maxRow = rows.reduce(max);
  final minCol = cols.reduce(min);
  final maxCol = cols.reduce(max);
  final crop = imglib.copyCrop(
    image,
    x: minRow,
    y: minCol,
    // TODO: +1?
    width: maxCol - minCol,
    height: maxRow - minRow,
  );
  return crop;
}

imglib.Image removeTransparent(Uint8List imageBytes) {
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

imglib.Image getBNWImage(imglib.Image image) {
  return imglib.adjustColor(
    imglib.grayscale(image),
    contrast: 1.8,
  );
}

imglib.Image increaseContrast(imglib.Image image) {
  final minmax = imglib.minMax(image);
  final min = minmax[0];
  final max = minmax[1];
  final range = max - min;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);

      final newRed = ((pixel.r - min) / range * 255).round().clamp(0, 255);
      final newGreen = ((pixel.g - min) / range * 255).round().clamp(0, 255);
      final newBlue = ((pixel.b - min) / range * 255).round().clamp(0, 255);

      image.setPixelRgb(x, y, newRed, newGreen, newBlue);
    }
  }

  return image;
}

imglib.Image getResize(imglib.Image image) {
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
    return resizeByRatio(image);
  }
}

imglib.Image increaseBrightness(imglib.Image image) {
  return imglib.adjustColor(image, brightness: 1.6);
}

imglib.Image decodeImage(Uint8List imageBytes) {
  // In contrast with the original,
  // I reorganized the pipeline as follows
  // because we have no need to accumulate in memory images for all the passed stages
  // (optimization purpose)
  final List<dynamic> stages = [
    removeTransparent,
    increaseContrast,
    getBNWImage,
    getResize,
    deleteEmptyBorders,
    centralSquareImage,
    increaseBrightness,
    // TODO: now have no impl for efn.preprocess_input(img)
  ];
  dynamic tmp = imageBytes;
  for (var stage in stages) {
    print(stage);
    tmp = stage(tmp);
  }
  return tmp;
}
