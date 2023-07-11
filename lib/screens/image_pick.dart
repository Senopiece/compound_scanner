import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  // these are remaining null in case camera is active with error
  Size? _latestCameraImageSize;
  double? _latestCameraImageScale;
  int? _latestCameraOrientation;
  CameraImage? _latestCameraImage;

  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<Uint8List?> _pickImage() async {
    final picker = ImagePicker();
    late XFile? pickedFile;
    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      // TODO: handle storage permission exception and other stuff
      print(e);
      return null;
    }
    if (pickedFile == null) {
      return null;
    }
    final res = await pickedFile.readAsBytes();
    return res;
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
          )
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    final pickedImageBytes = await _pickImage();
                    if (context.mounted && pickedImageBytes != null) {
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
                  child: const Icon(Icons.browse_gallery),
                ),
              ),
              const SizedBox(width: 30),
              SizedBox(
                width: 80,
                height: 80,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _latestCameraImage != null ? null : Colors.grey,
                  ),
                  onPressed: () {
                    if (_latestCameraImage == null) {
                      return;
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
                      x: (0.5 * (previewSize.width - selection.width / s))
                          .toInt(),
                      y: (0.5 * (previewSize.height - selection.height / s))
                          .toInt(),
                      width: selection.width ~/ s,
                      height: selection.height ~/ s,
                    );

                    // display it on a new screen.
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          maintainState: false,
                          builder: (context) => AnalysisScreen(
                            imageBytes: imglib.encodePng(cropped),
                          ),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.camera_alt),
                ),
              ),
              const SizedBox(width: 30),
              SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _latestCameraImage != null ? null : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _flash = !_flash;
                    });
                  },
                  child: _flash
                      ? const Icon(Icons.flash_off)
                      : const Icon(Icons.flash_on),
                ),
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
}
