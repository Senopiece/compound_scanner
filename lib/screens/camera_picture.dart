import 'dart:math';

import 'package:compound_scanner/screens/scan_result.dart';
import 'package:compound_scanner/utils/conversions.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../widgets/resizable_box.dart';
import 'package:image/image.dart' as imglib;

import 'package:image_picker/image_picker.dart';

class CameraPictureScreen extends StatefulWidget {
  const CameraPictureScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<CameraPictureScreen> createState() => _CameraPictureScreenState();
}

class _CameraPictureScreenState extends State<CameraPictureScreen> {
  bool _isCameraActive = true; // may be active, but still with error
  bool _flash = false;

  // these are remaining null in case camera is active with error
  Size? _latestCameraImageSize;
  double? _latestCameraImageScale;
  int? _latestCameraOrientation;
  CameraImage? _latestCameraImage;

  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  void _deactivateCamera() {
    setState(() {
      _isCameraActive = false;
      _latestCameraImageSize = null;
      _latestCameraImageScale = null;
      _latestCameraOrientation = null;
      _latestCameraImage = null;
    });
  }

  void _activateCamera() {
    setState(() {
      _isCameraActive = true;
    });
  }

  Future<imglib.Image?> _pickImage() async {
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
    final res = imglib.decodeImage(await pickedFile.readAsBytes());
    if (res == null) {
      print("TODO: alert got image, but cannot parse it");
      return null;
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraActive
          ? Stack(
              children: [
                _FullscreenCameraWidget(
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
                Center(child: ResizableBox(key: _resizableBoxKey))
              ],
            )
          : const Center(),
      // TODO: mv to stack with camera
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
                    _deactivateCamera();
                    final pickedImage = await _pickImage();
                    if (context.mounted && pickedImage != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          maintainState: false,
                          builder: (context) => ResultScreen(
                            imageBytes: imglib.encodePng(pickedImage),
                          ),
                        ),
                      );
                    } else {
                      _activateCamera();
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
                          builder: (context) => ResultScreen(
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

class _FullscreenCameraWidget extends StatefulWidget {
  final void Function(Size, double, int, CameraImage) onCameraImageCallback;
  final bool flash;

  const _FullscreenCameraWidget({
    Key? key,
    required this.flash,
    required this.onCameraImageCallback,
  }) : super(key: key);

  @override
  State<_FullscreenCameraWidget> createState() =>
      _FullscreenCameraWidgetState();
}

class _FullscreenCameraWidgetState extends State<_FullscreenCameraWidget> {
  late Future<void> _initializeControllerFuture;
  CameraController? _controller;
  double? cameraPreviewScale;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _ctrlFut();
  }

  @override
  void didUpdateWidget(covariant _FullscreenCameraWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller?.setFlashMode(widget.flash ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _ctrlFut() async {
    // TODO: in case no cam, report about it
    final cameras = await availableCameras();
    late CameraDescription frontCamera;
    for (CameraDescription camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        frontCamera = camera;
        break;
      }
    }
    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    await _controller!
        .setFlashMode(widget.flash ? FlashMode.torch : FlashMode.off);
    _controller!.startImageStream(
      (image) {
        if (cameraPreviewScale != null && _controller != null) {
          widget.onCameraImageCallback(_previewSize(), cameraPreviewScale!,
              _controller!.description.sensorOrientation, image);
        }
      },
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  Size _previewSize() {
    final so = _controller!.value.description.sensorOrientation;
    var previewSize = _controller!.value.previewSize!;
    if (so % 180 != 0) {
      // aka so in (90, 270)
      // need to swap orientation
      previewSize = Size(previewSize.height, previewSize.width);
    }
    return previewSize;
  }

  double _previewScale(Size contextSize, Size previewSize) {
    return max(
      contextSize.height / previewSize.height,
      contextSize.width / previewSize.width,
    ); // like BoxFit.cover
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            // TODO: check does it go here
            return const Center(child: Text("camera error"));
          }
          final size = MediaQuery.of(context).size;
          final previewSize = _previewSize();
          cameraPreviewScale = _previewScale(size, previewSize);
          return OverflowBox(
            minWidth: 0.0,
            minHeight: 0.0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: cameraPreviewScale! * previewSize.width,
              height: cameraPreviewScale! * previewSize.height,
              child: CameraPreview(_controller!),
            ),
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
