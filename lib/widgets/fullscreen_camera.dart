import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'jumping_dots.dart';

// TODO: blinking when camera permission is not granted (mb ImagePick problem)
class FullscreenCamera extends StatefulWidget {
  final void Function(Size, double, int, CameraImage) onCameraImageCallback;
  final bool flash;
  final bool pause;

  const FullscreenCamera({
    Key? key,
    required this.flash,
    required this.onCameraImageCallback,
    required this.pause,
  }) : super(key: key);

  @override
  State<FullscreenCamera> createState() => _FullscreenCameraState();
}

class _FullscreenCameraState extends State<FullscreenCamera>
    with WidgetsBindingObserver {
  bool wasPaused = false;
  Future<void>? _initializeControllerFuture;
  CameraController? _controller;
  double? cameraPreviewScale;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // filter only resume after paused
        // as it may go here also after inactive (that happens on rejected camera permission)
        if (wasPaused) {
          if (_initializeControllerFuture == null) {
            setState(() {
              _initializeControllerFuture = _ctrlFut();
            });
          } else {
            _initializeControllerFuture!.whenComplete(() {
              setState(() {
                _initializeControllerFuture = _ctrlFut();
              });
            });
          }
        }
        break;
      case AppLifecycleState.paused:
        _initializeControllerFuture?.whenComplete(() {
          setState(() {
            _initializeControllerFuture = null;
            _controller?.stopImageStream();
            _controller?.dispose();
            _controller = null;
          });
        });
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.detached:
        break;
    }
    wasPaused = (state == AppLifecycleState.paused);
  }

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _ctrlFut();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didUpdateWidget(covariant FullscreenCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller?.setFlashMode(widget.flash ? FlashMode.torch : FlashMode.off);
    _applyPaused();
  }

  Future<void> _ctrlFut() async {
    // TODO: in case no cam, report about it
    try {
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
      _applyPaused();
    } catch (e) {
      _controller?.dispose();
      _controller = null;
      rethrow;
    }
  }

  void _applyPaused() {
    if (_controller == null) return;
    if (widget.pause) {
      _controller!.pausePreview();
      if (_controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
      }
    } else {
      _controller!.resumePreview();
      if (!_controller!.value.isStreamingImages) {
        _controller!.startImageStream(
          (image) {
            if (cameraPreviewScale != null && _controller != null) {
              widget.onCameraImageCallback(_previewSize(), cameraPreviewScale!,
                  _controller!.description.sensorOrientation, image);
            }
          },
        );
      }
    }
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
            return const Center(child: Text("Camera Error"));
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
              child: _controller != null
                  ? CameraPreview(_controller!)
                  : const Center(),
            ),
          );
        } else {
          return const Center(child: ThreeDotsLoadingIndicator());
        }
      },
    );
  }
}
