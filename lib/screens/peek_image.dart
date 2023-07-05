import 'dart:math';

import 'package:compound_scanner/screens/scan_result.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

import '../widgets/resizable_box.dart';
import 'camera_picture.dart';

// TODO: scroll image too
class PeekImageScreen extends StatefulWidget {
  const PeekImageScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<PeekImageScreen> createState() => _PeekImageScreenState();
}

class _PeekImageScreenState extends State<PeekImageScreen> {
  img.Image? _pickedImage;
  final GlobalKey<ResizableBoxState> _resizableBoxKey =
      GlobalKey<ResizableBoxState>();

  Size _previewSize() {
    return Size(
      _pickedImage!.width.toDouble(),
      _pickedImage!.height.toDouble(),
    );
  }

  double _previewScale(Size contextSize, Size previewSize) {
    return max(contextSize.height / previewSize.height,
        contextSize.width / previewSize.width); // like BoxFit.cover
  }

  @override
  void initState() {
    super.initState();
    _pickImage().then(
      (pickedImage) {
        if (pickedImage == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              maintainState: false,
              builder: (context) => const CameraPictureScreen(),
            ),
          );
        } else {
          setState(() {
            _pickedImage = pickedImage;
          });
        }
      },
    );
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
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pickedImage != null
          ? Builder(
              builder: (context) {
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
                      child: Image.memory(
                        img.encodePng(_pickedImage!),
                        // yep, can be replaced by fit: cover
                        scale: 1 / s,
                        width: s * previewSize.width,
                        height: s * previewSize.height,
                      ),
                    ),
                    Center(
                      child: ResizableBox(
                        key: _resizableBoxKey,
                      ),
                    ), // TODO: not only resizable, but also shiftable
                  ],
                );
              },
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _pickedImage != null
          ? Column(
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
                          // reload this screen
                          setState(() {
                            final _backup = _pickedImage;
                            _pickedImage = null;
                            _pickImage().then((pickedImage) {
                              setState(() {
                                _pickedImage = pickedImage ?? _backup;
                              });
                            });
                          });
                        },
                        child: const Icon(Icons.browse_gallery),
                      ),
                    ),
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: FloatingActionButton(
                        heroTag: "submit",
                        onPressed: () {
                          // crop it
                          final size = MediaQuery.of(context).size;
                          final previewSize = _previewSize();
                          final s = _previewScale(size, previewSize);

                          final selection =
                              _resizableBoxKey.currentState!.getSize();

                          final cropped = img.copyCrop(
                            _pickedImage!,
                            x: (0.5 * (previewSize.width - selection.width / s))
                                .toInt(),
                            y: (0.5 *
                                    (previewSize.height - selection.height / s))
                                .toInt(),
                            width: selection.width ~/ s,
                            height: selection.height ~/ s,
                          );

                          // display it on a new screen.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              maintainState: false,
                              builder: (context) => ResultScreen(
                                imageBytes: img.encodePng(cropped),
                              ),
                            ),
                          );
                        },
                        child: const Icon(Icons.check),
                      ),
                    ),
                    const SizedBox(width: 30),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: FloatingActionButton(
                        heroTag: "dismiss",
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              maintainState: false,
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
            )
          : const SizedBox(),
    );
  }
}
