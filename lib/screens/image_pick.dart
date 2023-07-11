import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as imglib;
import 'package:image_picker/image_picker.dart';

import '../utils/conversions.dart';
import '../screens/analysis.dart';
import '../widgets/fullscreen_camera.dart';
import '../widgets/resizable_box.dart';

class ImagePickScreen extends StatefulWidget {
  const ImagePickScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<ImagePickScreen> createState() => _ImagePickScreenState();
}

class _ImagePickScreenState extends State<ImagePickScreen> {
  bool _flash = false;
  bool _flashBang = false;

  // these are remaining null in case camera is active with error
  Size? _latestCameraImageSize;
  double? _latestCameraImageScale;
  int? _latestCameraOrientation;
  CameraImage? _latestCameraImage;

  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  Future<Uint8List> _pickImage() async {
    late XFile? pickedFile;
    try {
      pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    } catch (e) {
      // TODO: handle storage permission exception and other stuff
      print(e);
      rethrow;
    }
    if (pickedFile == null) {
      throw "no image picked"; // TODO: test
    }
    return (await pickedFile.readAsBytes());
  }

  Uint8List _shotImage() {
    if (_latestCameraImage == null) {
      throw "shot invoked on a null camera";
    }

    // take the last preview frame
    final image = convertYUV420ToImage(
      _latestCameraImage!,
      rotation: _latestCameraOrientation!,
    );

    // crop it
    final previewSize = _latestCameraImageSize!;
    final s = _latestCameraImageScale!;

    final selection = _resizableBoxKey.currentState!.getSize();

    final cropped = imglib.copyCrop(
      image,
      x: (0.5 * (previewSize.width - selection.width / s)).toInt(),
      y: (0.5 * (previewSize.height - selection.height / s)).toInt(),
      width: selection.width ~/ s,
      height: selection.height ~/ s,
    );

    // and return encoded png
    return imglib.encodePng(cropped);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          FullscreenCamera(
            flash: _flash,
            onCameraImageCallback: (size, scale, orientation, img) {
              final preLatestCameraImage = _latestCameraImage;
              _latestCameraImageSize = size;
              _latestCameraImageScale = scale;
              _latestCameraOrientation = orientation;
              _latestCameraImage = img;
              if (preLatestCameraImage == null) setState(() {});
            },
          ),
          Container(color: _flashBang ? Colors.black : null),
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black54,
              BlendMode.srcOut,
            ),
            child: _latestCameraImage == null
                ? null
                : Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                      ),
                      Center(
                        child: ResizableBox(key: _resizableBoxKey),
                      ),
                    ],
                  ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: _latestCameraImage == null
                ? null
                : const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Text(
                      'Adjust the frame \n to fill with compound',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _button(
                child: Icon(
                  _flash ? Icons.flash_off : Icons.flash_on,
                  color: _latestCameraImage != null ? null : Colors.grey,
                ),
                onPressed: () {
                  if (_latestCameraImage != null) {
                    setState(() => _flash = !_flash);
                  }
                },
              ),
              const SizedBox(width: 30),
              SizedBox(
                width: 80,
                height: 80,
                child: ElevatedButton(
                  style: ButtonStyle(
                    padding: MaterialStateProperty.all<EdgeInsets>(
                      const EdgeInsets.all(8), // Set the desired padding
                    ),
                    shape: MaterialStateProperty.all<OutlinedBorder>(
                      const CircleBorder(),
                    ),
                    backgroundColor: MaterialStateProperty.all<Color>(
                      Colors.white.withOpacity(0.1),
                    ),
                    shadowColor: MaterialStateProperty.all(Colors.transparent),
                  ),
                  onPressed: () async {
                    setState(() => _flashBang = true);
                    await Future.delayed(const Duration(milliseconds: 30));
                    setState(() => _flashBang = false);
                    await Future.delayed(const Duration(milliseconds: 40));
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          maintainState: false,
                          builder: (context) => AnalysisScreen(
                            imageBytes: _shotImage(),
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _latestCameraImage != null
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 30),
              _button(
                child: const Icon(
                  Icons.image_search,
                ),
                onPressed: () async {
                  final pickedImageBytes = await _pickImage();
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        maintainState: false,
                        builder: (context) => AnalysisScreen(
                          imageBytes: pickedImageBytes,
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(
            height: 40,
          ),
        ],
      ),
    );
  }

  Widget _button({
    required Widget child,
    required void Function() onPressed,
  }) {
    return SizedBox(
      width: 60,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          shape: MaterialStateProperty.all<OutlinedBorder>(
            const CircleBorder(),
          ),
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: child,
      ),
    );
  }
}
