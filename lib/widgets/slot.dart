import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'blinker.dart';

class NoOverscrollIndicator extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class Slot extends StatelessWidget {
  final String label;
  final Stream<String> stream;

  const Slot({
    super.key,
    required this.label,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.all(8.0),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: StreamBuilder(
        stream: stream,
        builder: (context, snap) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 25,
                margin: const EdgeInsets.all(8),
                color: Colors.grey.shade400,
                padding: const EdgeInsets.all(3),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).cardColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                  stream: stream,
                  builder: (context, snap) {
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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  snap.data!,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                snap.connectionState != ConnectionState.done
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
              _copyButton(
                onPressed: snap.connectionState == ConnectionState.done &&
                        !snap.hasError
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
              ),
            ],
          );
        },
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
