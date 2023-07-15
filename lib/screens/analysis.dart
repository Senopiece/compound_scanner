import 'dart:async';
import 'package:compound_scanner/utils/fake.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image/image.dart' as imglib;

// import '../services/img_to_inchi.dart';
import '../services/img_to_smiles.dart';
import '../services/smiles_to_all.dart';
import '../widgets/blinker.dart';
import '../widgets/jumping_dots.dart';
import '../widgets/slot.dart';

class AnalysisScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const AnalysisScreen({Key? key, required this.imageBytes}) : super(key: key);

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late Stream<String> _smilesStream;
  late Stream<String> _inchiStream;
  late Stream<String> _iupakStream;

  var _resetKey = UniqueKey();

  List<Widget> _presentationsList = [];
  int _presentationsListIndex = 0; // currently displaying

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top],
    );
    initSmilesStream();
  }

  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageBytes != widget.imageBytes) {
      initSmilesStream();
    }
  }

  void initSmilesStream() {
    final smilesStreamController = StreamController<String>.broadcast();
    final inchiStreamController = StreamController<String>.broadcast();
    final iupakStreamController = StreamController<String>.broadcast();

    _smilesStream = smilesStreamController.stream;
    _inchiStream = inchiStreamController.stream;
    _iupakStream = iupakStreamController.stream;

    _presentationsList = [];
    _presentationsList.add(
      FittedBox(
        fit: BoxFit.contain,
        child: Image.memory(widget.imageBytes),
      ),
    ); // raw image from camera
    _presentationsList.add(
      const Center(child: ThreeDotsLoadingIndicator()),
    ); // preprocessed image
    _presentationsList.add(
      const Center(child: ThreeDotsLoadingIndicator()),
    ); // detected compound formula

    List<void Function(Object, StackTrace?)> errorHandles = [
      (e, _) => inchiStreamController.addError(e),
      (e, _) => iupakStreamController.addError(e),
      (_, _1) => setState(
            () {
              _presentationsList[2] = const Center(
                child: Text("Error"),
              );
            },
          ),
      (e, _) => smilesStreamController.addError(e),
      (_, _1) => setState(
            () {
              _presentationsList[1] = const Center(
                child: Text("Error"),
              );
            },
          ),
    ];

    void errorHandle(Object error, StackTrace? trace) {
      for (var handler in errorHandles) {
        handler(error, trace);
      }
    }

    () async {
      final converter = RestfulDecimerImageToSmiles(
        'http://192.168.0.201:6969/v1/models/decimer:predict',
      );

      // preprocess image
      late final imglib.Image preprocessedImg;
      try {
        preprocessedImg = await converter.preprocess(widget.imageBytes);
      } catch (e) {
        errorHandle(e, null);
        return;
      }

      setState(() {
        _presentationsList[1] = FittedBox(
          fit: BoxFit.contain,
          child: Image.memory(imglib.encodePng(preprocessedImg)),
        );
      });
      errorHandles.removeAt(4);

      // analyze
      converter.convert(preprocessedImg).listen(
        (event) {
          smilesStreamController.add(event);
        },
        onError: (error, trace) {
          errorHandle(error, trace);
        },
        onDone: () {
          smilesStreamController.close();
        },
      );

      final smiles = await smilesStreamController.stream.last;
      errorHandles.removeAt(3);

      // convert to other formats
      late All all;
      try {
        all = await smilesToAll(smiles);
      } catch (e) {
        errorHandle(e, null);
        return;
      }

      setState(() {
        _presentationsList[2] = FittedBox(
          fit: BoxFit.contain,
          child: Image.memory(all.image),
        );
      });

      fakeStream(all.inchi).listen(
        inchiStreamController.add,
        onError: inchiStreamController.addError,
        onDone: inchiStreamController.close,
      );

      fakeStream(all.iupac).listen(
        iupakStreamController.add,
        onError: iupakStreamController.addError,
        onDone: iupakStreamController.close,
      );
    }();
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _resetKey = UniqueKey();
      initSmilesStream();
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
                child: _presentationsList.elementAt(_presentationsListIndex),
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
              Slot(
                label: "SMILES",
                stream: _smilesStream,
              ),
              Slot(
                label: "InChI",
                stream: _inchiStream,
              ),
              Slot(
                label: "IUPAK",
                stream: _iupakStream,
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: Column(
        children: [
          const SizedBox(height: 10),
          _button(
            child: const Icon(Icons.flip_camera_android),
            onPressed: () {
              setState(() {
                _presentationsListIndex += 1;
                _presentationsListIndex %= _presentationsList.length;
              });
            },
          ),
        ],
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

  static Widget _button({
    required Widget child,
    required void Function() onPressed,
  }) {
    return SizedBox(
      width: 50,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ButtonStyle(
          shape: MaterialStateProperty.all<OutlinedBorder>(
            const CircleBorder(),
          ),
          backgroundColor: MaterialStateProperty.all(
            const Color.fromARGB(255, 23, 23, 23),
          ),
        ),
        child: child,
      ),
    );
  }
}
