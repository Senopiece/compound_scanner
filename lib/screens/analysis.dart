import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;

import '../services/img_to_inchi.dart';
import '../services/img_to_smiles.dart';
import '../widgets/blinker.dart';
import '../widgets/jumping_dots.dart';

class NoOverscrollIndicator extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class AnalysisScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const AnalysisScreen({Key? key, required this.imageBytes}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late Stream<String> _inchiStream;
  var _InChIcompleter = Completer<String>();
  late Future<Uint8List> _PreprocessedImageFut;
  var _resetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
    );
    initInchiStream();
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      initInchiStream();
    }
  }

  void initInchiStream() {
    // does not work
    // _inchiStream = imgToInchi(widget.imageBytes).asBroadcastStream();

    // instead do this
    final isController = StreamController<String>.broadcast();
    imgToInchi(widget.imageBytes).listen(
      (event) => isController.add(event),
      onError: (error) => isController.addError(error),
      onDone: () => isController.close(),
    );

    _inchiStream = isController.stream;
    _InChIcompleter = Completer<String>();
    _PreprocessedImageFut = preprocess(widget.imageBytes);
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _resetKey = UniqueKey();
      initInchiStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _resetKey,
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).canvasColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                color: const Color.fromARGB(255, 23, 23, 23),
                height: 300,
                width: double.infinity,
                child: FutureBuilder(
                  future: _PreprocessedImageFut,
                  builder: (context, snap) {
                    if (snap.hasData) {
                      return FittedBox(
                        fit: BoxFit.contain,
                        child: Image.memory(
                          snap.data!,
                        ),
                      );
                    } else if (snap.hasError) {
                      return const Center(
                        child: Text("Error"),
                      ); // TODO: beautify
                    } else {
                      return const Center(child: ThreeDotsLoadingIndicator());
                    }
                  },
                ),
              ),
              SizedBox(
                height: 70,
                child: StreamBuilder(
                  stream: _inchiStream,
                  builder: (context, snap) {
                    final children = <Widget>[];
                    bool done = false;
                    if (snap.hasData) {
                      final split = snap.data!.split('/');
                      done = split.length > 2 ||
                          snap.connectionState == ConnectionState.done;
                      if (split.length > 1) {
                        children.add(_chemText(split[1]));
                      }
                    }
                    if (!done) {
                      children.add(const BlinkingCursor(
                        cursorHeight: 24,
                        cursorWidth: 2.5,
                      ));
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: children,
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.all(8.0),
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      color: Colors.grey.shade400,
                      padding: const EdgeInsets.all(3),
                      child: Text(
                        "InChI",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).cardColor,
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder(
                        stream: _inchiStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.done) {
                            if (snap.hasError) {
                              _InChIcompleter.completeError(
                                snap.error!,
                                snap.stackTrace,
                              );
                            } else {
                              _InChIcompleter.complete(snap.data);
                            }
                          }

                          if (snap.hasError) {
                            debugPrint('${snap.error}');
                            debugPrintStack(stackTrace: snap.stackTrace);
                            return const Text("Error");
                          } else if (snap.hasData) {
                            return ScrollConfiguration(
                              behavior: NoOverscrollIndicator(),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  height: double.infinity,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        snap.data!,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      snap.connectionState !=
                                              ConnectionState.done
                                          ? const BlinkingCursor()
                                          : const SizedBox(),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const Row(
                              children: [
                                BlinkingCursor(),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                    FutureBuilder(
                      future: _InChIcompleter.future,
                      builder: (context, snap) {
                        return _copyButton(
                          onPressed: snap.hasData
                              ? () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: snap.data!));
                                  await Fluttertoast.cancel();
                                  Fluttertoast.showToast(
                                    msg: 'Text copied to clipboard',
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    timeInSecForIosWeb: 1,
                                  );
                                }
                              : null,
                        );
                      },
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chemText(String text) {
    final subs = {
      '0': '\u2080',
      '1': '\u2081',
      '2': '\u2082',
      '3': '\u2083',
      '4': '\u2084',
      '5': '\u2085',
      '6': '\u2086',
      '7': '\u2087',
      '8': '\u2088',
      '9': '\u2089',
    };

    // preprocess making each number subscript
    var modifiedText = "";
    for (var i = 0; i < text.length; i++) {
      modifiedText += subs.keys.contains(text[i]) ? subs[text[i]]! : text[i];
    }

    return Text(
      modifiedText,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static Widget _copyButton({
    void Function()? onPressed,
  }) {
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.fromLTRB(0, 4, 4, 4),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          backgroundColor: MaterialStateProperty.all(Colors.transparent),
          shadowColor: MaterialStateProperty.all(Colors.transparent),
        ),
        child: Transform.translate(
          offset: const Offset(-2, 0),
          child: const Icon(Icons.copy),
        ),
      ),
    );
  }
}
