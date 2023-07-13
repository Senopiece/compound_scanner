import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../services/img_to_inchi.dart';
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
  var _InChIcompleter = Completer<String>();
  var _resetKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
    );
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _resetKey = UniqueKey();
      _InChIcompleter = Completer<String>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _resetKey,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Scan Result"),
      ),
      backgroundColor: const Color.fromARGB(255, 50, 50, 50),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                color: const Color.fromARGB(255, 23, 23, 23),
                height: 300,
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.memory(widget.imageBytes),
                ),
              ),
              const SizedBox(
                height: 50,
                child: ThreeDotsLoadingIndicator(),
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
                        stream: imgToInchi(widget.imageBytes),
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
                                  child: Center(
                                    child: Text(
                                      snap.data!,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return const ThreeDotsLoadingIndicator();
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

  Widget _copyButton({
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
