import 'dart:math';

import 'package:compound_scanner/screens/scan_result.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../resizable_box.dart';
import 'camera_picture.dart';

class StaticImageScreen extends StatefulWidget {
  const StaticImageScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<StaticImageScreen> createState() => _StaticImageScreenState();
}

class _StaticImageScreenState extends State<StaticImageScreen> {
  late Future<img.Image?> _imagePicking;
  late img.Image _pickedImage;
  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  Size _previewSize() {
    return Size(_pickedImage.width.toDouble(), _pickedImage.height.toDouble());
  }

  double _previewScale(Size contextSize, Size previewSize) {
    return max(contextSize.height / previewSize.height,
        contextSize.width / previewSize.width); // like BoxFit.cover
  }

  @override
  void initState() {
    super.initState();
    _imagePicking = _pickImage();
  }

  Future<img.Image?> _pickImage() async {
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
    final res = img.decodeImage(await pickedFile.readAsBytes());
    if (res == null) {
      print("TODO: alert got image, but cannot parse it");
      return null;
    }
    _pickedImage = res;
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<img.Image?>(
        future: _imagePicking,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.data == null) {
              return const Center(child: Text("< No image selected >"));
            }

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
                    child: Image.memory(img.encodePng(snapshot.data!)),
                  ),
                ),
                Center(
                    child: ResizableBox(
                        key:
                            _resizableBoxKey)), // TODO: not only resizable, but also shiftable
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FutureBuilder<img.Image?>(
        future: _imagePicking,
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
                        onPressed: () {
                          // reload this screen
                          setState(() {
                            _imagePicking = _pickImage();
                          });
                        },
                        child: const Icon(Icons.browse_gallery),
                      ),
                    ),
                    const SizedBox(width: 30),
                    snapshot.data != null
                        ? SizedBox(
                            width: 80,
                            height: 80,
                            child: FloatingActionButton(
                              onPressed: () async {
                                // TODO: forbid to run concurrent shots
                                // crop it
                                final size = MediaQuery.of(context).size;
                                final previewSize = _previewSize();
                                final s = _previewScale(size, previewSize);

                                final selection =
                                    _resizableBoxKey.currentState!.getSize();

                                final cropped = img.copyCrop(
                                  _pickedImage,
                                  x: (0.5 *
                                          (previewSize.width -
                                              selection.width / s))
                                      .toInt(),
                                  y: (0.5 *
                                          (previewSize.height -
                                              selection.height / s))
                                      .toInt(),
                                  width: selection.width ~/ s,
                                  height: selection.height ~/ s,
                                );
                                final image =
                                    Image.memory(img.encodePng(cropped));

                                // display it on a new screen.
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ResultScreen(image: image),
                                  ),
                                );
                              },
                              child: const Icon(Icons.check),
                            ),
                          )
                        : const SizedBox(width: 30),
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: FloatingActionButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CameraPictureScreen(),
                            ),
                          );
                        },
                        child: const Icon(Icons.close),
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
