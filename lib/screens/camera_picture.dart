import 'dart:math';

import 'package:compound_scanner/screens/scan_result.dart';
import 'package:compound_scanner/screens/static_image.dart';
import 'package:compound_scanner/utils/conversions.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../resizable_box.dart';
import 'package:image/image.dart' as imglib;

class CameraPictureScreen extends StatefulWidget {
  const CameraPictureScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<CameraPictureScreen> createState() => _CameraPictureScreenState();
}

class _CameraPictureScreenState extends State<CameraPictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  CameraImage? _latestFrame;

  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _ctrlFut();
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
    await _controller.initialize();
    await _controller.startImageStream((image) => _latestFrame = image);
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    super.dispose();
  }

  Size _previewSize() {
    final so = _controller.value.description.sensorOrientation;
    var previewSize = _controller.value.previewSize!;
    if (so % 180 != 0) {
      // aka so in (90, 270)
      // need to swap orientation
      previewSize = Size(previewSize.height, previewSize.width);
    }
    return previewSize;
  }

  double _previewScale(Size contextSize, Size previewSize) {
    return max(contextSize.height / previewSize.height,
        contextSize.width / previewSize.width); // like BoxFit.cover
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final size = MediaQuery.of(context).size;
            final previewSize = _previewSize();
            final s = _previewScale(size, previewSize);
            return Stack(
              children: [
                OverflowBox(
                  minWidth: 0.0,
                  minHeight: 0.0,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: SizedBox(
                    width: s * previewSize.width,
                    height: s * previewSize.height,
                    child: CameraPreview(_controller),
                  ),
                ),
                Center(child: ResizableBox(key: _resizableBoxKey)),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: FloatingActionButton(
                        heroTag: "gallery",
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StaticImageScreen(),
                            ),
                          );
                        },
                        child: const Icon(Icons.browse_gallery),
                      ),
                    ),
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: FloatingActionButton(
                        heroTag: "shot",
                        onPressed: () async {
                          // TODO: forbid to run concurrent shots
                          await _initializeControllerFuture;

                          // take the last preview frame
                          final image = convertYUV420ToImage(
                            _latestFrame!,
                            rotation:
                                _controller.value.description.sensorOrientation,
                          );

                          // crop it
                          final size = MediaQuery.of(context).size;
                          final previewSize = _previewSize();
                          final s = _previewScale(size, previewSize);

                          final selection =
                              _resizableBoxKey.currentState!.getSize();

                          final cropped = imglib.copyCrop(
                            image,
                            x: (0.5 * (previewSize.width - selection.width / s))
                                .toInt(),
                            y: (0.5 *
                                    (previewSize.height - selection.height / s))
                                .toInt(),
                            width: selection.width ~/ s,
                            height: selection.height ~/ s,
                          );

                          // display it on a new screen.
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultScreen(
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
                      child: FloatingActionButton(
                        heroTag: "flash",
                        onPressed: () async {
                          await _initializeControllerFuture;
                          if (_controller.value.flashMode == FlashMode.off) {
                            await _controller.setFlashMode(FlashMode.torch);
                          } else {
                            await _controller.setFlashMode(FlashMode.off);
                          }
                          setState(() {});
                        },
                        child: _controller.value.flashMode == FlashMode.off
                            ? const Icon(Icons.flash_on)
                            : const Icon(Icons.flash_off),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 40,
                ),
              ],
            );
          } else {
            return const SizedBox();
          }
        },
      ),
    );
  }
}
